# frozen_string_literal: true

# name: discourse-ai
# about: TODO
# version: 0.0.1
# authors: Discourse
# url: TODO
# required_version: 2.7.0

enabled_site_setting :discourse_ai_enabled

require_relative "lib/discourse_ai/engine"

after_initialize do
  module ::DiscourseAI
    PLUGIN_NAME = "discourse-ai"
  end

  require_relative "lib/shared/inference/discourse_classifier"
  require_relative "lib/shared/inference/discourse_reranker"
  require_relative "lib/shared/inference/openai_completions"
  require_relative "lib/shared/inference/openai_embeddings"

  require_relative "lib/shared/classificator"
  require_relative "lib/shared/post_classificator"
  require_relative "lib/shared/chat_message_classificator"

  require_relative "lib/modules/nsfw/entry_point"
  require_relative "lib/modules/toxicity/entry_point"
  require_relative "lib/modules/sentiment/entry_point"

  [
    DiscourseAI::NSFW::EntryPoint.new,
    DiscourseAI::Toxicity::EntryPoint.new,
    DiscourseAI::Sentiment::EntryPoint.new,
  ].each do |a_module|
    a_module.load_files
    a_module.inject_into(self)
  end

  register_reviewable_type ReviewableAIChatMessage
  register_reviewable_type ReviewableAIPost

  on(:reviewable_transitioned_to) do |new_status, reviewable|
    ModelAccuracy.adjust_model_accuracy(new_status, reviewable)
  end
end
