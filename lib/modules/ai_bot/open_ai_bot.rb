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
        # note GPT counts both reply and request tokens in limits...
        # also allow for an extra 500 or so spare tokens
        if bot_user.id == DiscourseAi::AiBot::EntryPoint::GPT4_ID
          8192 - 3500
        else
          4096 - 2000
        end
      end

      def reply_params
        max_tokens =
          if bot_user.id == DiscourseAi::AiBot::EntryPoint::GPT4_ID
            3000
          else
            1500
          end

        { temperature: 0.4, top_p: 0.9, max_tokens: max_tokens }
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

        model = prefer_low_cost ? "gpt-3.5-turbo" : model_for
        DiscourseAi::Inference::OpenAiCompletions.perform!(prompt, model, **params, &blk)
      end

      def tokenize(text)
        DiscourseAi::Tokenizer::OpenAiTokenizer.tokenize(text)
      end

      def available_commands
        if bot_user.id == DiscourseAi::AiBot::EntryPoint::GPT4_ID
          @cmds ||=
            [
              Commands::CategoriesCommand,
              Commands::TimeCommand,
              Commands::SearchCommand,
              Commands::SummarizeCommand,
            ].tap do |cmds|
              cmds << Commands::TagsCommand if SiteSetting.tagging_enabled
              cmds << Commands::ImageCommand if SiteSetting.ai_stability_api_key.present?
              if SiteSetting.ai_google_custom_search_api_key.present? &&
                   SiteSetting.ai_google_custom_search_cx.present?
                cmds << Commands::GoogleCommand
              end
            end
        else
          []
        end
      end

      private

      def build_message(poster_username, content, system: false)
        is_bot = poster_username == bot_user.username

        if system
          role = "system"
        else
          role = is_bot ? "assistant" : "user"
        end

        { role: role, content: is_bot ? content : "#{poster_username}: #{content}" }
      end

      def model_for
        return "gpt-4" if bot_user.id == DiscourseAi::AiBot::EntryPoint::GPT4_ID
        "gpt-3.5-turbo"
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
