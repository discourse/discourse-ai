# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class OpenAiBot < Bot
      def self.can_reply_as?(bot_user)
        open_ai_bot_ids = [
          DiscourseAi::AiBot::EntryPoint::GPT4_ID,
          DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID,
        ]

        open_ai_bot_ids.include?(bot_user.id)
      end

      def prompt_limit
        # note this is about 100 tokens over, OpenAI have a more optimal representation
        @function_size ||= tokenize(available_functions.to_json).length

        # provide a buffer of 80 tokens - our function counting is not
        # 100% accurate so this is a trial and error number
        buffer = @function_size + reply_params[:max_tokens] + 80

        if bot_user.id == DiscourseAi::AiBot::EntryPoint::GPT4_ID
          8192 - buffer
        else
          16_384 - buffer
        end
      end

      def reply_params
        # technically we could allow GPT-3.5 16k more tokens
        # but lets just keep it here for now
        { temperature: 0.4, top_p: 0.9, max_tokens: 2500 }
      end

      def extra_tokens_per_message
        # open ai defines about 4 tokens per message of overhead
        4
      end

      def submit_prompt(
        prompt,
        prefer_low_cost: false,
        temperature: nil,
        top_p: nil,
        max_tokens: nil,
        &blk
      )
        params =
          reply_params.merge(
            temperature: temperature,
            top_p: top_p,
            max_tokens: max_tokens,
          ) { |key, old_value, new_value| new_value.nil? ? old_value : new_value }

        model = model_for(low_cost: prefer_low_cost)

        params[:functions] = available_functions if available_functions.present?

        DiscourseAi::Inference::OpenAiCompletions.perform!(prompt, model, **params, &blk)
      end

      def tokenizer
        DiscourseAi::Tokenizer::OpenAiTokenizer
      end

      def model_for(low_cost: false)
        return "gpt-4" if bot_user.id == DiscourseAi::AiBot::EntryPoint::GPT4_ID && !low_cost
        "gpt-3.5-turbo-16k"
      end

      def clean_username(username)
        if username.match?(/\0[a-zA-Z0-9_-]{1,64}\z/)
          username
        else
          # not the best in the world, but this is what we have to work with
          # if sites enable unicode usernames this can get messy
          username.gsub(/[^a-zA-Z0-9_-]/, "_")[0..63]
        end
      end

      def include_function_instructions_in_system_prompt?
        # open ai uses a bespoke system for function calls
        false
      end

      private

      def populate_functions(partial:, reply:, functions:, done:)
        return if !partial
        fn = partial.dig(:choices, 0, :delta, :function_call)
        if fn
          functions.add_function(fn[:name]) if fn[:name].present?
          functions.add_argument_fragment(fn[:arguments]) if !fn[:arguments].nil?
        end
      end

      def build_message(poster_username, content, function: false, system: false)
        is_bot = poster_username == bot_user.username

        if function
          role = "function"
        elsif system
          role = "system"
        else
          role = is_bot ? "assistant" : "user"
        end

        result = { role: role, content: content }

        if function
          result[:name] = poster_username
        elsif !system && poster_username != bot_user.username && poster_username.present?
          # Open AI restrict name to 64 chars and only A-Za-z._ (work around)
          result[:name] = clean_username(poster_username)
        end

        result
      end

      def get_delta(partial, _context)
        partial.dig(:choices, 0, :delta, :content).to_s
      end

      def get_updated_title(prompt)
        DiscourseAi::Inference::OpenAiCompletions.perform!(
          prompt,
          model_for,
          temperature: 0.7,
          top_p: 0.9,
          max_tokens: 40,
        ).dig(:choices, 0, :message, :content)
      end
    end
  end
end
