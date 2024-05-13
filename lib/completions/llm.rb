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
        def provider_names
          providers = %w[aws_bedrock anthropic vllm hugging_face cohere open_ai google azure]
          providers << "ollama" if Rails.env.development?
          providers
        end

        def tokenizer_names
          DiscourseAi::Completions::Dialects::Dialect.available_tokenizers.map(&:name).uniq
        end

        def models_by_provider
          # ChatGPT models are listed under open_ai but they are actually available through OpenAI and Azure.
          # However, since they use the same URL/key settings, there's no reason to duplicate them.
          @models_by_provider ||=
            {
              aws_bedrock: %w[
                claude-instant-1
                claude-2
                claude-3-haiku
                claude-3-sonnet
                claude-3-opus
              ],
              anthropic: %w[claude-instant-1 claude-2 claude-3-haiku claude-3-sonnet claude-3-opus],
              vllm: %w[mistralai/Mixtral-8x7B-Instruct-v0.1 mistralai/Mistral-7B-Instruct-v0.2],
              hugging_face: %w[
                mistralai/Mixtral-8x7B-Instruct-v0.1
                mistralai/Mistral-7B-Instruct-v0.2
              ],
              cohere: %w[command-light command command-r command-r-plus],
              open_ai: %w[
                gpt-3.5-turbo
                gpt-4
                gpt-3.5-turbo-16k
                gpt-4-32k
                gpt-4-turbo
                gpt-4-vision-preview
              ],
              google: %w[gemini-pro gemini-1.5-pro],
            }.tap do |h|
              h[:ollama] = ["mistral"] if Rails.env.development?
              h[:fake] = ["fake"] if Rails.env.test? || Rails.env.development?
            end
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

        def proxy(model_name)
          # We are in the process of transitioning to always use objects here.
          # We'll live with this hack for a while.
          provider_and_model_name = model_name.split(":")
          provider_name = provider_and_model_name.first
          model_name_without_prov = provider_and_model_name[1..].join
          is_custom_model = provider_name == "custom"

          if is_custom_model
            llm_model = LlmModel.find(model_name_without_prov)
            provider_name = llm_model.provider
            model_name_without_prov = llm_model.name
          end

          dialect_klass =
            DiscourseAi::Completions::Dialects::Dialect.dialect_for(model_name_without_prov)

          if is_custom_model
            tokenizer = llm_model.tokenizer_class
          else
            tokenizer = dialect_klass.tokenizer
          end

          if @canned_response
            if @canned_llm && @canned_llm != model_name
              raise "Invalid call LLM call, expected #{@canned_llm} but got #{model_name}"
            end
            return new(dialect_klass, nil, model_name, opts: { gateway: @canned_response })
          end

          opts = {}
          opts[:max_prompt_tokens] = llm_model.max_prompt_tokens if is_custom_model

          gateway_klass = DiscourseAi::Completions::Endpoints::Base.endpoint_for(provider_name)

          new(dialect_klass, gateway_klass, model_name_without_prov, opts: opts)
        end
      end

      def initialize(dialect_klass, gateway_klass, model_name, opts: {})
        @dialect_klass = dialect_klass
        @gateway_klass = gateway_klass
        @model_name = model_name
        @gateway = opts[:gateway]
        @max_prompt_tokens = opts[:max_prompt_tokens]
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

        gateway = @gateway || gateway_klass.new(model_name, dialect_klass.tokenizer)
        dialect =
          dialect_klass.new(
            prompt,
            model_name,
            opts: model_params.merge(max_prompt_tokens: @max_prompt_tokens),
          )
        gateway.perform_completion!(dialect, user, model_params, &partial_read_blk)
      end

      def max_prompt_tokens
        return @max_prompt_tokens if @max_prompt_tokens.present?

        dialect_klass.new(DiscourseAi::Completions::Prompt.new(""), model_name).max_prompt_tokens
      end

      delegate :tokenizer, to: :dialect_klass

      attr_reader :model_name

      private

      attr_reader :dialect_klass, :gateway_klass
    end
  end
end
