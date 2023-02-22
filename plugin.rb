# frozen_string_literal: true

# name: discourse-ai
# about: TODO
# version: 0.0.1
# authors: Discourse
# url: TODO
# required_version: 2.7.0

enabled_site_setting :ai_enabled

after_initialize do
  module ::Disorder
    PLUGIN_NAME = "discourse-ai"
  end

  require_relative "lib/shared/inference_manager.rb"
  require_relative "lib/modules/toxicity/event_handler.rb"
  require_relative "lib/modules/toxicity/classifier.rb"
  require_relative "lib/modules/toxicity/post_classifier.rb"
  require_relative "lib/modules/toxicity/chat_message_classifier.rb"
  require_relative "app/jobs/regular/modules/toxicity/toxicity_classify_post.rb"
  require_relative "app/jobs/regular/modules/toxicity/toxicity_classify_chat_message.rb"

  require_relative "lib/modules/sentiment/event_handler.rb"
  require_relative "lib/modules/sentiment/post_classifier.rb"
  require_relative "app/jobs/regular/modules/sentiment/sentiment_classify_post.rb"

  on(:post_created) do |post|
    DiscourseAI::Toxicity::EventHandler.handle_post_async(post)
    DiscourseAI::Sentiment::EventHandler.handle_post_async(post)
  end
  on(:post_edited) do |post|
    DiscourseAI::Toxicity::EventHandler.handle_post_async(post)
    DiscourseAI::Sentiment::EventHandler.handle_post_async(post)
  end
  on(:chat_message_created) do |chat_message|
    DiscourseAI::Toxicity::EventHandler.handle_chat_async(chat_message)
  end
  on(:chat_message_edited) do |chat_message|
    DiscourseAI::Toxicity::EventHandler.handle_chat_async(chat_message)
  end
end
