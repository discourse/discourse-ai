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
    class LLM
      UNKNOWN_MODEL = Class.new(StandardError)

      def self.with_prepared_responses(responses)
        @canned_response = DiscourseAi::Completions::Endpoints::CannedResponse.new(responses)

        yield(@canned_response).tap { @canned_response = nil }
      end

      def self.proxy(model_name)
        dialects = [
          DiscourseAi::Completions::Dialects::Claude,
          DiscourseAi::Completions::Dialects::Llama2Classic,
          DiscourseAi::Completions::Dialects::ChatGPT,
          DiscourseAi::Completions::Dialects::OrcaStyle,
        ]

        dialect =
          dialects.detect(-> { raise UNKNOWN_MODEL }) { |d| d.can_translate?(model_name) }.new

        return new(dialect, @canned_response, model_name) if @canned_response

        gateway =
          DiscourseAi::Completions::Endpoints::Base.endpoint_for(model_name).new(
            model_name,
            dialect.tokenizer,
          )

        new(dialect, gateway, model_name)
      end

      def initialize(dialect, gateway, model_name)
        @dialect = dialect
        @gateway = gateway
        @model_name = model_name
      end

      delegate :tokenizer, to: :dialect

      # @param generic_prompt { Hash } - Prompt using our generic format.
      # We use the following keys from the hash:
      #   - insts: String with instructions for the LLM.
      #   - input: String containing user input
      #   - examples (optional): Array of arrays with examples of input and responses. Each array is a input/response pair like [[example1, response1], [example2, response2]].
      #   - post_insts (optional): Additional instructions for the LLM. Some dialects like Claude add these at the end of the prompt.
      #
      # @param user { User } - User requesting the summary.
      #
      # @param &on_partial_blk { Block - Optional } - The passed block will get called with the LLM partial response alongside a cancel function.
      #
      # @returns { String } - Completion result.
      def completion!(generic_prompt, user, &partial_read_blk)
        prompt = dialect.translate(generic_prompt)

        model_params = generic_prompt.dig(:params, model_name) || {}

        gateway.perform_completion!(prompt, user, model_params, &partial_read_blk)
      end

      private

      attr_reader :dialect, :gateway, :model_name
    end
  end
end
