# frozen_string_literal: true

module DiscourseAi
  module Completions
    class LLM
      UNKNOWN_MODEL = Class.new(StandardError)

      def self.with_prepared_response(response)
        @canned_response = DiscourseAi::Completions::Endpoints::CannedResponse.new(response)

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
