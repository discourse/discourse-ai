# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class TopicHelper
      def initialize(input, user, params = {})
        @user = user
        @text = input[:text]
        @params = params
      end

      def explain
        return nil if @text.blank?
        return nil unless post = Post.find_by(id: @params[:post_id])

        reply_to = post.topic.first_post
        topic = reply_to.topic

        llm_prompt =
          DiscourseAi::AiHelper::LlmPrompt.new.available_prompts(name_filter: "explain").first
        prompt = CompletionPrompt.find_by(id: llm_prompt[:id])

        prompt.messages.first["content"].gsub!("{{search}}", @text)
        prompt.messages.first["content"].gsub!("{{context}}", post.raw)
        prompt.messages.first["content"].gsub!("{{topic}}", topic.title)
        # TODO inject this conditionally
        #prompt.messages.first["content"].gsub!("{{post}}", reply_to.raw)

        DiscourseAi::AiHelper::LlmPrompt.new.generate_and_send_prompt(prompt, nil)
      end
    end
  end
end
