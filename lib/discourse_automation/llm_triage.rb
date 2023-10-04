# frozen_string_literal: true

if defined?(DiscourseAutomation)
  module DiscourseAutomation::LlmTriage
    def self.handle(
      post:,
      model:,
      search_for_text:,
      system_prompt:,
      category_id: nil,
      tags: nil,
      canned_reply: nil,
      canned_reply_user: nil,
      hide_topic: nil
    )
      if category_id.blank? && tags.blank? && canned_reply.blank? && hide_topic.blank?
        raise ArgumentError, "llm_triage: no action specified!"
      end

      post_template = +""
      post_template << "title: #{post.topic.title}\n"
      post_template << "#{post.raw}"

      filled_system_prompt = system_prompt.sub("%%POST%%", post_template)

      if filled_system_prompt == system_prompt
        raise ArgumentError, "llm_triage: system_prompt does not contain %%POST%% placeholder"
      end

      result = nil
      if model == "claude-2"
        # allowing double + 10 tokens
        # technically maybe just token count is fine, but this will allow for more creative bad responses
        result =
          DiscourseAi::Inference::AnthropicCompletions.perform!(
            filled_system_prompt,
            model,
            temperature: 0,
            max_tokens:
              DiscourseAi::Tokenizer::AnthropicTokenizer.tokenize(search_for_text).length * 2 + 10,
          ).dig(:completion)
      else
        result =
          DiscourseAi::Inference::OpenAiCompletions.perform!(
            [{ :role => "system", "content" => filled_system_prompt }],
            model,
            temperature: 0,
            max_tokens:
              DiscourseAi::Tokenizer::OpenAiTokenizer.tokenize(search_for_text).length * 2 + 10,
          ).dig(:choices, 0, :message, :content)
      end

      if result.strip == search_for_text.strip
        user = User.find_by_username(canned_reply_user) if canned_reply_user.present?
        user = user || Discourse.system_user
        if canned_reply.present?
          PostCreator.create!(
            user,
            topic_id: post.topic_id,
            raw: canned_reply,
            reply_to_post_number: post.post_number,
            skip_validations: true,
          )
        end

        changes = {}
        changes[:category_id] = category_id if category_id.present?
        changes[:tags] = tags if SiteSetting.tagging_enabled? && tags.present?

        if changes.present?
          first_post = post.topic.posts.where(post_number: 1).first
          changes[:bypass_bump] = true
          changes[:skip_validations] = true
          first_post.revise(Discourse.system_user, changes)
        end

        post.topic.update!(visible: false) if hide_topic
      end
    end
  end

  DiscourseAutomation::Scriptable::LLM_TRIAGE = "llm_triage"

  AVAILABLE_MODELS = [
    {
      id: "gpt-4",
      name:
        "discourse_automation.scriptables.#{DiscourseAutomation::Scriptable::LLM_TRIAGE}.models.gpt_4",
    },
    {
      id: "gpt-3-5-turbo",
      name:
        "discourse_automation.scriptables.#{DiscourseAutomation::Scriptable::LLM_TRIAGE}.models.gpt_3_5_turbo",
    },
    {
      id: "claude-2",
      name:
        "discourse_automation.scriptables.#{DiscourseAutomation::Scriptable::LLM_TRIAGE}.models.claude_2",
    },
  ]

  DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scriptable::LLM_TRIAGE) do
    version 1
    run_in_background

    placeholder :post

    triggerables %i[post_created_edited]

    field :system_prompt,
          component: :message,
          required: true,
          validator: ->(input) {
            if !input.include?("%%POST%%")
              I18n.t(
                "discourse_automation.scriptables.#{DiscourseAutomation::Scriptable::LLM_TRIAGE}.system_prompt_missing_post_placeholder",
              )
            end
          },
          accepts_placeholders: true
    field :search_for_text, component: :text, required: true
    field :model, component: :choices, required: true, extra: { content: AVAILABLE_MODELS }
    field :category, component: :category
    field :tags, component: :tags
    field :hide_topic, component: :boolean
    field :canned_reply, component: :message
    field :canned_reply_user, component: :user

    script do |context, fields, automation|
      post = context["post"]
      system_prompt = fields["system_prompt"]["value"]
      search_for_text = fields["search_for_text"]["value"]
      model = fields["model"]["value"]

      if !%w[gpt-4 gpt-3-5-turbo claude-2].include?(model)
        Rails.logger.warn("llm_triage: model #{model} is not supported")
        next
      end

      category_id = fields.dig("category", "value")
      tags = fields.dig("tags", "value")
      hide_topic = fields.dig("hide_topic", "value")
      canned_reply = fields.dig("canned_reply", "value")
      canned_reply_user = fields.dig("canned_reply_user", "value")

      if post.raw.strip == canned_reply.to_s.strip
        # nothing to do if we already replied
        next
      end

      begin
        DiscourseAutomation::LlmTriage.handle(
          post: post,
          model: model,
          search_for_text: search_for_text,
          system_prompt: system_prompt,
          category_id: category_id,
          tags: tags,
          canned_reply: canned_reply,
          canned_reply_user: canned_reply_user,
          hide_topic: hide_topic,
        )
      rescue => e
        Discourse.warn_exception(e, message: "llm_triage: failed to run inference")
      end
    end
  end
end
