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
        #
        # 2500 are the max reply tokens
        # Then we have 450 or so for the full function suite
        # 100 additional for growth around function calls
        if bot_user.id == DiscourseAi::AiBot::EntryPoint::GPT4_ID
          8192 - 3050
        else
          16_384 - 3050
        end
      end

      def reply_params
        # technically we could allow GPT-3.5 16k more tokens
        # but lets just keep it here for now
        { temperature: 0.4, top_p: 0.9, max_tokens: 2500 }
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

      def tokenize(text)
        DiscourseAi::Tokenizer::OpenAiTokenizer.tokenize(text)
      end

      def available_functions
        # note if defined? can be a problem in test
        # this can never be nil so it is safe
        return @available_functions if @available_functions

        functions = []

        functions =
          available_commands.map do |command|
            function =
              DiscourseAi::Inference::OpenAiCompletions::Function.new(
                name: command.name,
                description: command.desc,
              )
            command.parameters.each do |parameter|
              function.add_parameter(
                name: parameter.name,
                type: parameter.type,
                description: parameter.description,
                required: parameter.required,
              )
            end
            function
          end

        @available_functions = functions
      end

      def available_commands
        return @cmds if @cmds

        all_commands =
          [
            Commands::CategoriesCommand,
            Commands::TimeCommand,
            Commands::SearchCommand,
            Commands::SummarizeCommand,
            Commands::ReadCommand,
          ].tap do |cmds|
            cmds << Commands::TagsCommand if SiteSetting.tagging_enabled
            cmds << Commands::ImageCommand if SiteSetting.ai_stability_api_key.present?
            if SiteSetting.ai_google_custom_search_api_key.present? &&
                 SiteSetting.ai_google_custom_search_cx.present?
              cmds << Commands::GoogleCommand
            end
          end

        allowed_commands = SiteSetting.ai_bot_enabled_chat_commands.split("|")
        @cmds = all_commands.filter { |klass| allowed_commands.include?(klass.name) }
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

      private

      def populate_functions(partial, functions)
        fn = partial.dig(:choices, 0, :delta, :function_call)
        if fn
          functions.add_function(fn[:name]) if fn[:name].present?
          functions.add_argument_fragment(fn[:arguments]) if fn[:arguments].present?
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
