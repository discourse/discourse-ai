# frozen_string_literal: true

if defined?(DiscourseAutomation)
  DiscourseAutomation::Scriptable.add("llm_triage") do
    version 1
    run_in_background

    placeholder :post

    triggerables %i[post_created_edited]

    field :system_prompt, component: :message, required: false
    field :search_for_text, component: :text, required: true
    field :model,
          component: :choices,
          required: true,
          extra: {
            content: DiscourseAi::Automation.available_models,
          }
    field :category, component: :category
    field :tags, component: :tags
    field :hide_topic, component: :boolean
    field :hide_post, component: :boolean
    field :flag_post, component: :boolean
    field :canned_reply, component: :message
    field :canned_reply_user, component: :user

    script do |context, fields|
      post = context["post"]
      canned_reply = fields.dig("canned_reply", "value")
      canned_reply_user = fields.dig("canned_reply_user", "value")

      # nothing to do if we already replied
      next if post.user.username == canned_reply_user
      next if post.raw.strip == canned_reply.to_s.strip

      system_prompt = fields["system_prompt"]["value"]
      search_for_text = fields["search_for_text"]["value"]
      model = fields["model"]["value"]

      category_id = fields.dig("category", "value")
      tags = fields.dig("tags", "value")
      hide_topic = fields.dig("hide_topic", "value")
      hide_post = fields.dig("hide_post", "value")
      flag_post = fields.dig("flag_post", "value")

      begin
        RateLimiter.new(
          Discourse.system_user,
          "llm_triage_#{post.id}",
          SiteSetting.ai_automation_max_triage_per_post_per_minute,
          1.minute,
        ).performed!

        RateLimiter.new(
          Discourse.system_user,
          "llm_triage",
          SiteSetting.ai_automation_max_triage_per_minute,
          1.minute,
        ).performed!

        DiscourseAi::Automation::LlmTriage.handle(
          post: post,
          model: model,
          search_for_text: search_for_text,
          system_prompt: system_prompt,
          category_id: category_id,
          tags: tags,
          canned_reply: canned_reply,
          canned_reply_user: canned_reply_user,
          hide_topic: hide_topic,
          hide_post: hide_post,
          flag_post: flag_post,
          automation: self.automation,
        )
      rescue => e
        Discourse.warn_exception(e, message: "llm_triage: skipped triage on post #{post.id}")
      end
    end
  end
end
