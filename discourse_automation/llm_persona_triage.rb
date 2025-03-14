# frozen_string_literal: true

if defined?(DiscourseAutomation)
  DiscourseAutomation::Scriptable.add("llm_persona_triage") do
    version 1
    run_in_background

    triggerables %i[post_created_edited]

    field :persona,
          component: :choices,
          required: true,
          extra: {
            content: DiscourseAi::Automation.available_persona_choices,
          }
    field :whisper, component: :boolean

    script do |context, fields|
      post = context["post"]
      next if post&.user&.bot?

      persona_id = fields["persona"]["value"]
      whisper = fields["whisper"]["value"]

      begin
        RateLimiter.new(
          Discourse.system_user,
          "llm_persona_triage_#{post.id}",
          SiteSetting.ai_automation_max_triage_per_post_per_minute,
          1.minute,
        ).performed!

        RateLimiter.new(
          Discourse.system_user,
          "llm_persona_triage",
          SiteSetting.ai_automation_max_triage_per_minute,
          1.minute,
        ).performed!

        DiscourseAi::Automation::LlmPersonaTriage.handle(
          post: post,
          persona_id: persona_id,
          whisper: whisper,
          automation: self.automation,
        )
      rescue => e
        Discourse.warn_exception(
          e,
          message: "llm_persona_triage: skipped triage on post #{post.id}",
        )
        raise e if Rails.env.tests?
      end
    end
  end
end
