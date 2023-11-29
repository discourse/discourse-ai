# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class TopicHelper
      def initialize(user)
        @user = user
      end

      def explain(term_to_explain, post)
        return nil unless term_to_explain
        return nil unless post

        reply_to = post.reply_to_post
        topic = post.topic

        prompt = CompletionPrompt.enabled_by_name("explain")
        raise Discourse::InvalidParameters.new(:mode) if !prompt

        input = <<~TEXT
          <term>#{term_to_explain}</term>
          <context>#{post.raw}</context>
          <topic>#{topic.title}</topic>
          #{reply_to ? "<replyTo>#{reply_to.raw}</replyTo>" : nil}
        TEXT

        DiscourseAi::AiHelper::Assistant.new.generate_and_send_prompt(prompt, input, user)
      end

      private

      attr_reader :user
    end
  end
end
