# frozen_string_literal: true

module Jobs
  class StreamPostHelper < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless post = Post.includes(:topic).find_by(id: args[:post_id])
      return unless user = User.find_by(id: args[:user_id])
      return unless args[:term_to_explain]

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

      DiscourseAi::AiHelper::Assistant.new.stream_prompt(
        prompt,
        input,
        user,
        "/discourse-ai/ai-helper/explain/#{post.id}",
      )
    end
  end
end
