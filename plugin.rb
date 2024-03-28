# frozen_string_literal: true

# name: discourse-ai
# about: Enables integration between AI modules and features in Discourse
# meta_topic_id: 259214
# version: 0.0.1
# authors: Discourse
# url: https://meta.discourse.org/t/discourse-ai/259214
# required_version: 2.7.0

gem "tokenizers", "0.4.3"
gem "tiktoken_ruby", "0.0.7"
gem "baran", "0.1.10"

enabled_site_setting :discourse_ai_enabled

register_asset "stylesheets/modules/ai-helper/common/ai-helper.scss"

register_asset "stylesheets/modules/ai-bot/common/bot-replies.scss"
register_asset "stylesheets/modules/ai-bot/common/ai-persona.scss"
register_asset "stylesheets/modules/ai-bot/mobile/ai-persona.scss", :mobile

register_asset "stylesheets/modules/embeddings/common/semantic-related-topics.scss"
register_asset "stylesheets/modules/embeddings/common/semantic-search.scss"

register_asset "stylesheets/modules/sentiment/common/dashboard.scss"
register_asset "stylesheets/modules/sentiment/desktop/dashboard.scss", :desktop
register_asset "stylesheets/modules/sentiment/mobile/dashboard.scss", :mobile

module ::DiscourseAi
  PLUGIN_NAME = "discourse-ai"
end

Rails.autoloaders.main.push_dir(File.join(__dir__, "lib"), namespace: ::DiscourseAi)

require_relative "lib/engine"

after_initialize do
  # do not autoload this cause we may have no namespace
  require_relative "discourse_automation/llm_triage"
  require_relative "discourse_automation/llm_report"

  add_admin_route("discourse_ai.title", "discourse-ai", { use_new_show_route: true })

  [
    DiscourseAi::Embeddings::EntryPoint.new,
    DiscourseAi::Nsfw::EntryPoint.new,
    DiscourseAi::Toxicity::EntryPoint.new,
    DiscourseAi::Sentiment::EntryPoint.new,
    DiscourseAi::AiHelper::EntryPoint.new,
    DiscourseAi::Summarization::EntryPoint.new,
    DiscourseAi::AiBot::EntryPoint.new,
  ].each { |a_module| a_module.inject_into(self) }

  register_reviewable_type ReviewableAiChatMessage
  register_reviewable_type ReviewableAiPost

  on(:reviewable_transitioned_to) do |new_status, reviewable|
    ModelAccuracy.adjust_model_accuracy(new_status, reviewable)
  end

  if Rails.env.test?
    require_relative "spec/support/embeddings_generation_stubs"
    require_relative "spec/support/stable_diffusion_stubs"
  end

  reloadable_patch { |plugin| Guardian.prepend DiscourseAi::GuardianExtensions }
end
