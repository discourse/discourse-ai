# frozen_string_literal: true

# name: discourse-ai
# about: TODO
# version: 0.0.1
# authors: Discourse
# url: TODO
# required_version: 2.7.0

enabled_site_setting :discourse_ai_enabled

after_initialize do
  module ::DiscourseAI
    PLUGIN_NAME = "discourse-ai"
  end

  require_relative "lib/shared/inference_manager.rb"

  require_relative "lib/modules/nsfw/entry_point.rb"
  require_relative "lib/modules/toxicity/entry_point.rb"
  require_relative "lib/modules/sentiment/entry_point.rb"

  modules = [
    DiscourseAI::NSFW::EntryPoint,
    DiscourseAI::Toxicity::EntryPoint,
    DiscourseAI::Sentiment::EntryPoint,
  ]

  modules.each { |a_module| a_module.new.inject_into(self) }
end
