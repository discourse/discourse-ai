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
        def presets
          # Sam: I am not sure if it makes sense to translate model names at all
          @presets ||=
            begin
              [
                {
                  id: "anthropic",
                  models: [
                    {
                      name: "claude-3-5-sonnet",
                      tokens: 200_000,
                      display_name: "Claude 3.5 Sonnet",
                    },
                    { name: "claude-3-opus", tokens: 200_000, display_name: "Claude 3 Opus" },
                    { name: "claude-3-sonnet", tokens: 200_000, display_name: "Claude 3 Sonnet" },
                    { name: "claude-3-haiku", tokens: 200_000, display_name: "Claude 3 Haiku" },
                  ],
                  tokenizer: DiscourseAi::Tokenizer::AnthropicTokenizer,
                  endpoint: "https://api.anthropic.com/v1/messages",
                  provider: "anthropic",
                },
                {
                  id: "google",
                  models: [
                    {
                      name: "gemini-1.5-pro",
                      tokens: 800_000,
                      endpoint:
                        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest",
                      display_name: "Gemini 1.5 Pro",
                    },
                    {
                      name: "gemini-1.5-flash",
                      tokens: 800_000,
                      endpoint:
                        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest",
                      display_name: "Gemini 1.5 Flash",
                    },
                  ],
                  tokenizer: DiscourseAi::Tokenizer::OpenAiTokenizer,
                  provider: "google",
                },
                {
                  id: "open_ai",
                  models: [
                    { name: "gpt-4o", tokens: 131_072, display_name: "GPT-4 Omni" },
                    { name: "gpt-4o-mini", tokens: 131_072, display_name: "GPT-4 Omni Mini" },
                    { name: "gpt-4-turbo", tokens: 131_072, display_name: "GPT-4 Turbo" },
                  ],
                  tokenizer: DiscourseAi::Tokenizer::OpenAiTokenizer,
                  endpoint: "https://api.openai.com/v1/chat/completions",
                  provider: "open_ai",
                },
              ]
            end
        end

        def provider_names
          providers = %w[
            aws_bedrock
            anthropic
            vllm
            hugging_face
            cohere
            open_ai
            google
            azure
            samba_nova
          ]
          if !Rails.env.production?
            providers << "fake"
            providers << "ollama"
          end

          providers
        end

        def tokenizer_names
          DiscourseAi::Tokenizer::BasicTokenizer.available_llm_tokenizers.map(&:name)
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
          @prompts = []

          yield(@canned_response, llm, @prompts)
        ensure
          # Don't leak prepared response if there's an exception.
          @canned_response = nil
          @canned_llm = nil
          @prompts = nil
        end

        def record_prompt(prompt)
          @prompts << prompt if @prompts
        end

        def proxy(model)
          llm_model =
            if model.is_a?(LlmModel)
              model
            else
              model_name_without_prov = model.split(":").last.to_i

              LlmModel.find_by(id: model_name_without_prov)
            end

          raise UNKNOWN_MODEL if llm_model.nil?

          model_provider = llm_model.provider
          dialect_klass = DiscourseAi::Completions::Dialects::Dialect.dialect_for(model_provider)

          if @canned_response
            if @canned_llm && @canned_llm != model
              raise "Invalid call LLM call, expected #{@canned_llm} but got #{model}"
            end

            return new(dialect_klass, nil, llm_model, gateway: @canned_response)
          end

          gateway_klass = DiscourseAi::Completions::Endpoints::Base.endpoint_for(model_provider)

          new(dialect_klass, gateway_klass, llm_model)
        end
      end

      def initialize(dialect_klass, gateway_klass, llm_model, gateway: nil)
        @dialect_klass = dialect_klass
        @gateway_klass = gateway_klass
        @gateway = gateway
        @llm_model = llm_model
      end

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
        feature_name: nil,
        &partial_read_blk
      )
        self.class.record_prompt(prompt)

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

        dialect = dialect_klass.new(prompt, llm_model, opts: model_params)

        gateway = @gateway || gateway_klass.new(llm_model)
        gateway.perform_completion!(
          dialect,
          user,
          model_params,
          feature_name: feature_name,
          &partial_read_blk
        )
      end

      def max_prompt_tokens
        llm_model.max_prompt_tokens
      end

      def tokenizer
        llm_model.tokenizer_class
      end

      attr_reader :llm_model

      private

      attr_reader :dialect_klass, :gateway_klass
    end
  end
end
