# frozen_string_literal: true

if defined?(DiscourseAutomation)
  DiscourseAutomation::Scriptable.add("llm_tool_triage") do
    version 1
    run_in_background

    triggerables %i[post_created_edited]

    field :tool,
          component: :choices,
          required: true,
          extra: {
            content: DiscourseAi::Automation.available_custom_tools,
          }

    script do |context, fields|
      tool_id = fields["tool"]["value"]
      post = context["post"]

      begin
        RateLimiter.new(
          Discourse.system_user,
          "llm_tool_triage_#{post.id}",
          SiteSetting.ai_automation_max_triage_per_post_per_minute,
          1.minute,
        ).performed!

        RateLimiter.new(
          Discourse.system_user,
          "llm_tool_triage",
          SiteSetting.ai_automation_max_triage_per_minute,
          1.minute,
        ).performed!

        DiscourseAi::Automation::LlmToolTriage.handle(
          post: post,
          tool_id: tool_id,
          automation: self.automation,
        )
      rescue => e
        Discourse.warn_exception(e, message: "llm_tool_triage: skipped triage on post #{post.id}")
      end
    end
  end
end
