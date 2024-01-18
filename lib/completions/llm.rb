# frozen_string_literal: true

# A facade that abstracts multiple LLMs behind a single interface.
#
# Internally, it consists of the combination of a dialect and an endpoint.
# After receiving a prompt using our generic format, it translates it to
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

        yield(@canned_response)
      ensure
        # Don't leak prepared response if there's an exception.
        @canned_response = nil
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

      # @param generic_prompt { DiscourseAi::Completions::Prompt } - Our generic prompt object
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
      def generate(
        prompt,
        temperature: nil,
        max_tokens: nil,
        stop_sequences: nil,
        user:,
        &partial_read_blk
      )
        model_params = {
          temperature: temperature,
          max_tokens: max_tokens,
          stop_sequences: stop_sequences,
        }

        if prompt.is_a?(String)
          prompt =
            DiscourseAi::Completions::Prompt.new(
              "You are a helpful bot",
              messages: [{ type: :user, content: prompt }],
            )
        elsif prompt.is_a?(Array)
          prompt = DiscourseAi::Completions::Prompt.new(messages: prompt)
        end

        if !prompt.is_a?(DiscourseAi::Completions::Prompt)
          raise ArgumentError, "Prompt must be either a string, array, of Prompt object"
        end

        model_params.keys.each { |key| model_params.delete(key) if model_params[key].nil? }

        dialect = dialect_klass.new(prompt, model_name, opts: model_params)
        gateway.perform_completion!(dialect, user, model_params, &partial_read_blk)
      end

      def max_prompt_tokens
        dialect_klass.new(DiscourseAi::Completions::Prompt.new(""), model_name).max_prompt_tokens
      end

      attr_reader :model_name

      private

      attr_reader :dialect_klass, :gateway
    end
  end
end
