# frozen_string_literal: true

# A facade that abstracts multiple LLMs behind a single interface.
#
# Internally, it consists of the combination of a dialect and an endpoint.
# After receiving a prompt using our generic format, it translates it to
# the target model and routes the completion request through the correct gateway.
#
# Use the .proxy method to instantiate an object.
# It chooses the correct dialect and endpoint for the model you want to interact with.
#
# Tests of modules that perform LLM calls can use .with_prepared_responses to return canned responses
# instead of relying on WebMock stubs like we did in the past.
#
module DiscourseAi
  module Completions
    class Llm
      UNKNOWN_MODEL = Class.new(StandardError)

      class << self
        def models_by_provider
          # ChatGPT models are listed under open_ai but they are actually available through OpenAI and Azure.
          # However, since they use the same URL/key settings, there's no reason to duplicate them.
          @models_by_provider ||=
            {
              aws_bedrock: %w[claude-instant-1 claude-2],
              anthropic: %w[claude-instant-1 claude-2],
              vllm: %w[
                mistralai/Mixtral-8x7B-Instruct-v0.1
                mistralai/Mistral-7B-Instruct-v0.2
                StableBeluga2
                Upstage-Llama-2-*-instruct-v2
                Llama2-*-chat-hf
                Llama2-chat-hf
              ],
              hugging_face: %w[
                mistralai/Mixtral-8x7B-Instruct-v0.1
                mistralai/Mistral-7B-Instruct-v0.2
                StableBeluga2
                Upstage-Llama-2-*-instruct-v2
                Llama2-*-chat-hf
                Llama2-chat-hf
              ],
              open_ai: %w[
                gpt-3.5-turbo
                gpt-4
                gpt-3.5-turbo-16k
                gpt-4-32k
                gpt-4-turbo
                gpt-4-vision-preview
              ],
              google: %w[gemini-pro],
            }.tap { |h| h[:fake] = ["fake"] if Rails.env.test? || Rails.env.development? }
        end

        def valid_provider_models
          return @valid_provider_models if defined?(@valid_provider_models)

          valid_provider_models = []
          models_by_provider.each do |provider, models|
            valid_provider_models.concat(models.map { |model| "#{provider}:#{model}" })
          end
          @valid_provider_models = Set.new(valid_provider_models)
        end

        def with_prepared_responses(responses, llm: nil)
          @canned_response = DiscourseAi::Completions::Endpoints::CannedResponse.new(responses)
          @canned_llm = llm

          yield(@canned_response, llm)
        ensure
          # Don't leak prepared response if there's an exception.
          @canned_response = nil
          @canned_llm = nil
        end

        def proxy(model_name)
          provider_and_model_name = model_name.split(":")

          provider_name = provider_and_model_name.first
          model_name_without_prov = provider_and_model_name[1..].join

          dialect_klass =
            DiscourseAi::Completions::Dialects::Dialect.dialect_for(model_name_without_prov)

          if @canned_response
            if @canned_llm && @canned_llm != model_name
              raise "Invalid call LLM call, expected #{@canned_llm} but got #{model_name}"
            end
            return new(dialect_klass, @canned_response, model_name)
          end

          gateway =
            DiscourseAi::Completions::Endpoints::Base.endpoint_for(
              provider_name,
              model_name_without_prov,
            ).new(model_name_without_prov, dialect_klass.tokenizer)

          new(dialect_klass, gateway, model_name_without_prov)
        end
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
        top_p: nil,
        max_tokens: nil,
        stop_sequences: nil,
        user:,
        &partial_read_blk
      )
        model_params = { max_tokens: max_tokens, stop_sequences: stop_sequences }

        model_params[:temperature] = temperature if temperature
        model_params[:top_p] = top_p if top_p

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
