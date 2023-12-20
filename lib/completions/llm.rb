# frozen_string_literal: true

# A facade that abstracts multiple LLMs behind a single interface.
#
# Internally, it consists of the combination of a dialect and an endpoint.
# After recieving a prompt using our generic format, it translates it to
# the target model and routes the completion request through the correct gateway.
#
# Use the .proxy method to instantiate an object.
# It chooses the best dialect and endpoint for the model you want to interact with.
#
# Tests of modules that perform LLM calls can use .with_prepared_responses to return canned responses
# instead of relying on WebMock stubs like we did in the past.
#
module DiscourseAi
  module Completions
    class Llm
      UNKNOWN_MODEL = Class.new(StandardError)

      def self.with_prepared_responses(responses)
        @canned_response = DiscourseAi::Completions::Endpoints::CannedResponse.new(responses)

        yield(@canned_response).tap { @canned_response = nil }
      end

      def self.proxy(model_name)
        dialect_klass = DiscourseAi::Completions::Dialects::Dialect.dialect_for(model_name)

        return new(dialect_klass, @canned_response, model_name) if @canned_response

        gateway =
          DiscourseAi::Completions::Endpoints::Base.endpoint_for(model_name).new(
            model_name,
            dialect_klass.tokenizer,
          )

        new(dialect_klass, gateway, model_name)
      end

      def initialize(dialect_klass, gateway, model_name)
        @dialect_klass = dialect_klass
        @gateway = gateway
        @model_name = model_name
      end

      delegate :tokenizer, to: :dialect_klass

      # @param generic_prompt { Hash } - Prompt using our generic format.
      # We use the following keys from the hash:
      #   - insts: String with instructions for the LLM.
      #   - input: String containing user input
      #   - examples (optional): Array of arrays with examples of input and responses. Each array is a input/response pair like [[example1, response1], [example2, response2]].
      #   - post_insts (optional): Additional instructions for the LLM. Some dialects like Claude add these at the end of the prompt.
      #   - conversation_context (optional): Array of hashes to provide context about an ongoing conversation with the model.
      #     We translate the array in reverse order, meaning the first element would be the most recent message in the conversation.
      #     Example:
      #
      #   [
      #    { type: "user", name: "user1", content: "This is a new message by a user" },
      #    { type: "assistant", content: "I'm a previous bot reply, that's why there's no user" },
      #    { type: "tool", name: "tool_id", content: "I'm a tool result" },
      #   ]
      #
      #   - tools (optional - only functions supported): Array of functions a model can call. Each function is defined as a hash. Example:
      #
      #     {
      #       name: "get_weather",
      #       description: "Get the weather in a city",
      #       parameters: [
      #         { name: "location", type: "string", description: "the city name", required: true },
      #         {
      #           name: "unit",
      #           type: "string",
      #           description: "the unit of measurement celcius c or fahrenheit f",
      #           enum: %w[c f],
      #           required: true,
      #         },
      #       ],
      #     }
      #
      # @param user { User } - User requesting the summary.
      #
      # @param &on_partial_blk { Block - Optional } - The passed block will get called with the LLM partial response alongside a cancel function.
      #
      # @returns { String } - Completion result.
      #
      # When the model invokes a tool, we'll wait until the endpoint finishes replying and feed you a fully-formed tool,
      # even if you passed a partial_read_blk block. Invocations are strings that look like this:
      #
      # <function_calls>
      #   <invoke>
      #   <tool_name>get_weather</tool_name>
      #   <tool_id>get_weather</tool_id>
      #   <parameters>
      #     <location>Sydney</location>
      #     <unit>c</unit>
      #   </parameters>
      #  </invoke>
      # </function_calls>
      #
      def completion!(generic_prompt, user, &partial_read_blk)
        model_params = generic_prompt.dig(:params, model_name) || {}

        dialect = dialect_klass.new(generic_prompt, model_name, opts: model_params)

        gateway.perform_completion!(dialect, user, model_params, &partial_read_blk)
      end

      private

      attr_reader :dialect_klass, :gateway, :model_name
    end
  end
end
