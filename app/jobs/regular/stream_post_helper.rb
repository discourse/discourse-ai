# frozen_string_literal: true

module Jobs
  class StreamPostHelper < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless post = Post.includes(:topic).find_by(id: args[:post_id])
      return unless user = User.find_by(id: args[:user_id])
      topic = post.topic
      reply_to = post.reply_to_post

      guardian = Guardian.new(user)
      return unless guardian.can_see?(post)
      
      prompt = CompletionPrompt.enabled_by_name("explain")
      llm = DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_helper_model)

      input = <<~TEXT
      <term>#{args[:term_to_explain]}</term>
      <context>#{post.raw}</context>
          <topic>#{topic.title}</topic>
          #{reply_to ? "<replyTo>#{reply_to.raw}</replyTo>" : nil}
        TEXT

      generic_prompt = completion_prompt.messages_with_input(input)
      
      streamed_result = +""
      llm.completion!(generic_prompt, user) do |partial_response, cancel_function|
        streamed_result << partial_response
        payload = { result: streamed_result }

        publish_update(post, user, payload)
      end
    end

    private

    def publish_update(post, user, payload)
      MessageBus.publish("discourse-ai/ai-helper/explain/#{post.id}", payload, user_ids: [user.id])
    end
  end
end
