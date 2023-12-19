# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class Assistant
      def available_prompts(name_filter: nil)
        cp = CompletionPrompt

        prompts = name_filter ? [cp.enabled_by_name(name_filter)] : cp.where(enabled: true)

        prompts.map do |prompt|
          translation =
            I18n.t("discourse_ai.ai_helper.prompts.#{prompt.name}", default: nil) ||
              prompt.translated_name || prompt.name

          {
            id: prompt.id,
            name: prompt.name,
            translated_name: translation,
            prompt_type: prompt.prompt_type,
            icon: icon_map(prompt.name),
            location: location_map(prompt.name),
          }
        end
      end

      def generate_prompt(completion_prompt, input, user, &block)
        llm = DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_helper_model)
        generic_prompt = completion_prompt.messages_with_input(input)

        llm.completion!(generic_prompt, user, &block)
      end

      def generate_and_send_prompt(completion_prompt, input, user)
        completion_result = generate_prompt(completion_prompt, input, user)
        result = { type: completion_prompt.prompt_type }

        result[:diff] = parse_diff(input, completion_result) if completion_prompt.diff?

        result[:suggestions] = (
          if completion_prompt.list?
            parse_list(completion_result).map { |suggestion| sanitize_result(suggestion) }
          else
            [sanitize_result(completion_result)]
          end
        )

        result
      end

      def stream_prompt(completion_prompt, input, user, channel)
        streamed_result = +""
        start = Time.now

        generate_prompt(completion_prompt, input, user) do |partial_response, cancel_function|
          streamed_result << partial_response

          # Throttle the updates
          if (Time.now - start > 0.5) || Rails.env.test?
            payload = { result: sanitize_result(streamed_result), done: false }
            publish_update(channel, payload, user)
            start = Time.now
          end
        end

        sanitized_result = sanitize_result(streamed_result)
        if sanitized_result.present?
          publish_update(channel, { result: sanitized_result, done: true }, user)
        end
      end

      private

      def sanitize_result(result)
        tags_to_remove = %w[
          <term>
          </term>
          <context>
          </context>
          <topic>
          </topic>
          <replyTo>
          </replyTo>
          <input>
          </input>
          <output>
          </output>
          <result>
          </result>
        ]

        result.dup.tap { |dup_result| tags_to_remove.each { |tag| dup_result.gsub!(tag, "") } }
      end

      def publish_update(channel, payload, user)
        MessageBus.publish(channel, payload, user_ids: [user.id])
      end

      def icon_map(name)
        case name
        when "translate"
          "language"
        when "generate_titles"
          "heading"
        when "proofread"
          "spell-check"
        when "markdown_table"
          "table"
        when "tone"
          "microphone"
        when "custom_prompt"
          "comment"
        when "rewrite"
          "pen"
        when "explain"
          "question"
        when "illustrate_post"
          "images"
        else
          nil
        end
      end

      def location_map(name)
        case name
        when "translate"
          %w[composer post]
        when "generate_titles"
          %w[composer]
        when "proofread"
          %w[composer post]
        when "markdown_table"
          %w[composer]
        when "tone"
          %w[composer]
        when "custom_prompt"
          %w[composer post]
        when "rewrite"
          %w[composer]
        when "explain"
          %w[post]
        when "summarize"
          %w[post]
        when "illustrate_posts"
          %w[composer]
        else
          %w[composer post]
        end
      end

      def parse_diff(text, suggestion)
        cooked_text = PrettyText.cook(text)
        cooked_suggestion = PrettyText.cook(suggestion)

        DiscourseDiff.new(cooked_text, cooked_suggestion).inline_html
      end

      def parse_list(list)
        Nokogiri::HTML5.fragment(list).css("item").map(&:text)
      end
    end
  end
end
