# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class Bot
      class FunctionCalls
        attr_accessor :maybe_buffer, :maybe_found, :custom

        def initialize
          @functions = []
          @current_function = nil
          @found = false
          @cancel_completion = false
          @maybe_buffer = +""
          @maybe_found = false
          @custom = false
        end

        def custom?
          @custom
        end

        def found?
          !@functions.empty? || @found
        end

        def found!
          @found = true
        end

        def maybe_found?
          @maybe_found
        end

        def cancel_completion?
          @cancel_completion
        end

        def cancel_completion!
          @cancel_completion = true
        end

        def add_function(name)
          @current_function = { name: name, arguments: +"" }
          @functions << @current_function
        end

        def add_argument_fragment(fragment)
          @current_function[:arguments] << fragment
        end

        def length
          @functions.length
        end

        def each
          @functions.each { |function| yield function }
        end

        def to_a
          @functions
        end
      end

      attr_reader :bot_user, :persona

      BOT_NOT_FOUND = Class.new(StandardError)
      MAX_COMPLETIONS = 5

      def self.as(bot_user, persona_id: nil, persona_name: nil, user: nil)
        available_bots = [DiscourseAi::AiBot::OpenAiBot, DiscourseAi::AiBot::AnthropicBot]

        bot =
          available_bots.detect(-> { raise BOT_NOT_FOUND }) do |bot_klass|
            bot_klass.can_reply_as?(bot_user)
          end

        persona = nil
        if persona_id
          persona = DiscourseAi::AiBot::Personas.find_by(user: user, id: persona_id)
          raise BOT_NOT_FOUND if persona.nil?
        end

        if !persona && persona_name
          persona = DiscourseAi::AiBot::Personas.find_by(user: user, name: persona_name)
          raise BOT_NOT_FOUND if persona.nil?
        end

        bot.new(bot_user, persona: persona&.new)
      end

      def initialize(bot_user, persona: nil)
        @bot_user = bot_user
        @persona = persona || DiscourseAi::AiBot::Personas::General.new
      end

      def update_pm_title(post)
        prompt = title_prompt(post)

        new_title = get_updated_title(prompt).strip.split("\n").last

        PostRevisor.new(post.topic.first_post, post.topic).revise!(
          bot_user,
          title: new_title.sub(/\A"/, "").sub(/"\Z/, ""),
        )
        post.topic.custom_fields.delete(DiscourseAi::AiBot::EntryPoint::REQUIRE_TITLE_UPDATE)
        post.topic.save_custom_fields
      end

      def reply_to(
        post,
        total_completions: 0,
        bot_reply_post: nil,
        prefer_low_cost: false,
        standalone: false
      )
        return if total_completions > MAX_COMPLETIONS

        # do not allow commands when we are at the end of chain (total completions == MAX_COMPLETIONS)
        allow_commands = (total_completions < MAX_COMPLETIONS)

        prompt =
          if standalone && post.post_custom_prompt
            username, standalone_prompt = post.post_custom_prompt.custom_prompt.last
            [build_message(username, standalone_prompt)]
          else
            bot_prompt_with_topic_context(post, allow_commands: allow_commands)
          end

        redis_stream_key = nil
        partial_reply = +""
        reply = +(bot_reply_post ? bot_reply_post.raw.dup : "")
        start = Time.now

        setup_cancel = false
        context = {}
        functions = FunctionCalls.new

        submit_prompt(prompt, post: post, prefer_low_cost: prefer_low_cost) do |partial, cancel|
          current_delta = get_delta(partial, context)
          partial_reply << current_delta

          if !available_functions.empty?
            populate_functions(
              partial: partial,
              reply: partial_reply,
              functions: functions,
              current_delta: current_delta,
              done: false,
            )

            cancel&.call if functions.cancel_completion?
          end

          if functions.maybe_buffer.present? && !functions.maybe_found?
            reply << functions.maybe_buffer
            functions.maybe_buffer = +""
          end

          reply << current_delta if !functions.found? && !functions.maybe_found?

          if redis_stream_key && !Discourse.redis.get(redis_stream_key)
            cancel&.call

            bot_reply_post.update!(raw: reply, cooked: PrettyText.cook(reply)) if bot_reply_post
          end

          # Minor hack to skip the delay during tests.
          next if (Time.now - start < 0.5) && !Rails.env.test?

          if bot_reply_post
            Discourse.redis.expire(redis_stream_key, 60)
            start = Time.now

            publish_update(bot_reply_post, raw: reply.dup)
          else
            bot_reply_post =
              PostCreator.create!(
                bot_user,
                topic_id: post.topic_id,
                raw: reply,
                skip_validations: true,
              )
          end

          if !setup_cancel && bot_reply_post
            redis_stream_key = "gpt_cancel:#{bot_reply_post.id}"
            Discourse.redis.setex(redis_stream_key, 60, 1)
            setup_cancel = true
          end
        end

        if !available_functions.empty?
          populate_functions(
            partial: nil,
            reply: partial_reply,
            current_delta: "",
            functions: functions,
            done: true,
          )
        end

        if functions.maybe_buffer.present?
          reply << functions.maybe_buffer
          functions.maybe_buffer = +""
        end

        if bot_reply_post
          publish_update(bot_reply_post, done: true)

          bot_reply_post.revise(
            bot_user,
            { raw: reply },
            skip_validations: true,
            skip_revision: true,
          )

          bot_reply_post.post_custom_prompt ||= post.build_post_custom_prompt(custom_prompt: [])
          prompt = post.post_custom_prompt.custom_prompt || []

          truncated_reply = partial_reply

          # TODO: we may want to move this code
          if functions.length > 0 && partial_reply.include?("</invoke>")
            # recover stop word potentially
            truncated_reply =
              partial_reply.split("</invoke>").first + "</invoke>\n</function_calls>"
          end

          prompt << [truncated_reply, bot_user.username] if truncated_reply.present?

          post.post_custom_prompt.update!(custom_prompt: prompt)
        end

        if functions.length > 0
          chain = false
          standalone = false

          functions.each do |function|
            name, args = function[:name], function[:arguments]

            if command_klass = available_commands.detect { |cmd| cmd.invoked?(name) }
              command =
                command_klass.new(
                  bot: self,
                  args: args,
                  post: bot_reply_post,
                  parent_post: post,
                  xml_format: !functions.custom?,
                )
              chain_intermediate, bot_reply_post = command.invoke!
              chain ||= chain_intermediate
              standalone ||= command.standalone?
            end
          end

          if chain
            reply_to(
              bot_reply_post,
              total_completions: total_completions + 1,
              bot_reply_post: bot_reply_post,
              standalone: standalone,
            )
          end
        end
      rescue => e
        if Rails.env.development?
          p e
          puts e.backtrace
        end
        raise e if Rails.env.test?
        Discourse.warn_exception(e, message: "ai-bot: Reply failed")
      end

      def extra_tokens_per_message
        0
      end

      def bot_prompt_with_topic_context(post, allow_commands:)
        messages = []
        conversation = conversation_context(post)

        rendered_system_prompt = system_prompt(post, allow_commands: allow_commands)
        total_prompt_tokens = tokenize(rendered_system_prompt).length + extra_tokens_per_message

        prompt_limit = self.prompt_limit(allow_commands: allow_commands)

        conversation.each do |raw, username, function|
          break if total_prompt_tokens >= prompt_limit

          tokens = tokenize(raw.to_s + username.to_s)

          while !raw.blank? &&
                  tokens.length + total_prompt_tokens + extra_tokens_per_message > prompt_limit
            raw = raw[0..-100] || ""
            tokens = tokenize(raw.to_s + username.to_s)
          end

          next if raw.blank?

          total_prompt_tokens += tokens.length + extra_tokens_per_message
          messages.unshift(build_message(username, raw, function: !!function))
        end

        messages.unshift(build_message(bot_user.username, rendered_system_prompt, system: true))

        messages
      end

      def prompt_limit(allow_commands: false)
        raise NotImplemented
      end

      def title_prompt(post)
        prompt = <<~TEXT
          You are titlebot. Given a topic you will figure out a title.
          You will never respond with anything but a 7 word topic title.
        TEXT
        messages = [build_message(bot_user.username, prompt, system: true)]

        messages << build_message("User", <<~TEXT)
          Suggest a 7 word title for the following topic without quoting any of it:

          <content>
          #{post.topic.posts.map(&:raw).join("\n\n")[0..prompt_limit(allow_commands: false)]}
          </content>
        TEXT
        messages
      end

      def available_commands
        @persona.available_commands
      end

      def system_prompt_style!(style)
        @style = style
      end

      def system_prompt(post, allow_commands:)
        return "You are a helpful Bot" if @style == :simple

        @persona.render_system_prompt(
          topic: post.topic,
          allow_commands: allow_commands,
          render_function_instructions:
            allow_commands && include_function_instructions_in_system_prompt?,
        )
      end

      def include_function_instructions_in_system_prompt?
        true
      end

      def function_list
        @persona.function_list
      end

      def tokenizer
        raise NotImplemented
      end

      def tokenize(text)
        tokenizer.tokenize(text)
      end

      def submit_prompt(
        prompt,
        post:,
        prefer_low_cost: false,
        temperature: nil,
        max_tokens: nil,
        &blk
      )
        raise NotImplemented
      end

      def get_delta(partial, context)
        raise NotImplemented
      end

      def populate_functions(partial:, reply:, functions:, done:, current_delta:)
        if !done
          search_length = "<function_calls>".length
          index = -1
          while index > -search_length
            substr = reply[index..-1] || reply
            index -= 1

            functions.maybe_found = "<function_calls>".start_with?(substr)
            break if functions.maybe_found?
          end

          functions.maybe_buffer << current_delta if functions.maybe_found?
          functions.found! if reply.match?(/^<function_calls>/i)
          if functions.found?
            functions.maybe_buffer = functions.maybe_buffer.to_s.split("<")[0..-2].join("<")
            functions.cancel_completion! if reply.match?(%r{</function_calls>}i)
          end
        else
          functions_string = reply.scan(%r{(<function_calls>(.*?)</invoke>)}im)&.first&.first
          if functions_string
            function_list
              .parse_prompt(functions_string + "</function_calls>")
              .each do |function|
                functions.add_function(function[:name])
                functions.add_argument_fragment(function[:arguments].to_json)
              end
          end
        end
      end

      def available_functions
        @persona.available_functions
      end

      protected

      def get_updated_title(prompt)
        raise NotImplemented
      end

      def model_for(bot)
        raise NotImplemented
      end

      def conversation_context(post)
        context =
          post
            .topic
            .posts
            .includes(:user)
            .joins("LEFT JOIN post_custom_prompts ON post_custom_prompts.post_id = posts.id")
            .where("post_number <= ?", post.post_number)
            .order("post_number desc")
            .where("post_type = ?", Post.types[:regular])
            .limit(50)
            .pluck(:raw, :username, "post_custom_prompts.custom_prompt")

        result = []

        first = true
        context.each do |raw, username, custom_prompt|
          if custom_prompt.present?
            if first
              custom_prompt.reverse_each { |message| result << message }
              first = false
            else
              result << custom_prompt.first
            end
          else
            result << [raw, username]
          end
        end

        result
      end

      def publish_update(bot_reply_post, payload)
        MessageBus.publish(
          "discourse-ai/ai-bot/topic/#{bot_reply_post.topic_id}",
          payload.merge(post_id: bot_reply_post.id, post_number: bot_reply_post.post_number),
          user_ids: bot_reply_post.topic.allowed_user_ids,
        )
      end
    end
  end
end
