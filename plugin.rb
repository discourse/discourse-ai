# frozen_string_literal: true

# name: discourse-ai
# about: Enables integration between AI modules and features in Discourse
# meta_topic_id: 259214
# version: 0.0.1
# authors: Discourse
# url: https://meta.discourse.org/t/discourse-ai/259214
# required_version: 2.7.0

gem "tokenizers", "0.4.4"
gem "tiktoken_ruby", "0.0.9"
gem "ed25519", "1.2.4" #TODO remove this as existing ssl gem should handle this

# we probably want to move all dependencies directly in to the Discourse Gemfile, this
# will give us a strong guarantee that the dependencies are compatible and keep getting upgraded
gem "Ascii85", "2.0.1", require: false
gem "ruby-rc4", "0.1.5", require: false
gem "hashery", "2.1.2", require: false
gem "ttfunk", "1.8.0", require: false
gem "afm", "0.2.2", require: false
# all above are required by pdf-reader
gem "pdf-reader", "2.14.1", require: false

enabled_site_setting :discourse_ai_enabled

register_asset "stylesheets/common/streaming.scss"
register_asset "stylesheets/common/ai-blinking-animation.scss"

register_asset "stylesheets/modules/ai-helper/common/ai-helper.scss"
register_asset "stylesheets/modules/ai-helper/desktop/ai-helper-fk-modals.scss", :desktop
register_asset "stylesheets/modules/ai-helper/mobile/ai-helper.scss", :mobile

register_asset "stylesheets/modules/summarization/common/ai-summary.scss"
register_asset "stylesheets/modules/summarization/desktop/ai-summary.scss", :desktop

register_asset "stylesheets/modules/summarization/common/ai-gists.scss"

register_asset "stylesheets/modules/ai-bot/common/bot-replies.scss"
register_asset "stylesheets/modules/ai-bot/common/ai-persona.scss"
register_asset "stylesheets/modules/ai-bot/common/ai-discobot-discoveries.scss"
register_asset "stylesheets/modules/ai-bot/mobile/ai-persona.scss", :mobile

register_asset "stylesheets/modules/embeddings/common/semantic-related-topics.scss"
register_asset "stylesheets/modules/embeddings/common/semantic-search.scss"

register_asset "stylesheets/modules/sentiment/common/dashboard.scss"

register_asset "stylesheets/modules/llms/common/ai-llms-editor.scss"
register_asset "stylesheets/modules/embeddings/common/ai-embedding-editor.scss"

register_asset "stylesheets/modules/llms/common/usage.scss"
register_asset "stylesheets/modules/llms/common/spam.scss"
register_asset "stylesheets/modules/llms/common/ai-llm-quotas.scss"

register_asset "stylesheets/modules/ai-bot/common/ai-tools.scss"

register_asset "stylesheets/modules/ai-bot/common/ai-artifact.scss"

module ::DiscourseAi
  PLUGIN_NAME = "discourse-ai"

  def self.public_asset_path(name)
    File.expand_path(File.join(__dir__, "public", name))
  end
end

Rails.autoloaders.main.push_dir(File.join(__dir__, "lib"), namespace: ::DiscourseAi)

require_relative "lib/engine"

after_initialize do
  if defined?(Rack::MiniProfiler)
    Rack::MiniProfiler.config.skip_paths << "/discourse-ai/ai-bot/artifacts"
  end

  # do not autoload this cause we may have no namespace
  require_relative "discourse_automation/llm_triage"
  require_relative "discourse_automation/llm_report"
  require_relative "discourse_automation/llm_tool_triage"
  require_relative "discourse_automation/llm_persona_triage"

  add_admin_route("discourse_ai.title", "discourse-ai", { use_new_show_route: true })

  [
    DiscourseAi::Embeddings::EntryPoint.new,
    DiscourseAi::Sentiment::EntryPoint.new,
    DiscourseAi::AiHelper::EntryPoint.new,
    DiscourseAi::Summarization::EntryPoint.new,
    DiscourseAi::AiBot::EntryPoint.new,
    DiscourseAi::AiModeration::EntryPoint.new,
  ].each { |a_module| a_module.inject_into(self) }

  register_problem_check ProblemCheck::AiLlmStatus

  register_reviewable_type ReviewableAiChatMessage
  register_reviewable_type ReviewableAiPost

  on(:reviewable_transitioned_to) do |new_status, reviewable|
    ModelAccuracy.adjust_model_accuracy(new_status, reviewable)
    if DiscourseAi::AiModeration::SpamScanner.enabled?
      DiscourseAi::AiModeration::SpamMetric.update(new_status, reviewable)
    end
  end

  if Rails.env.test?
    require_relative "spec/support/embeddings_generation_stubs"
    require_relative "spec/support/stable_diffusion_stubs"
  end

  reloadable_patch do |plugin|
    Guardian.prepend DiscourseAi::GuardianExtensions
    Topic.prepend DiscourseAi::TopicExtensions
    Post.prepend DiscourseAi::PostExtensions
  end

  register_modifier(:post_should_secure_uploads?) do |_, _, topic|
    if topic.private_message? && SharedAiConversation.exists?(target: topic)
      false
    else
      # revert to default behavior
      # even though this can be shortened this is the clearest way to express it
      nil
    end
  end

  plugin_icons = %w[
    chart-column
    spell-check
    language
    images
    far-copy
    robot
    info
    bars-staggered
    far-circle-question
    face-smile
    face-meh
    face-angry
  ]
  plugin_icons.each { |icon| register_svg_icon(icon) }
end
