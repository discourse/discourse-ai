# frozen_string_literal: true

# name: discourse-ai
# about: TODO
# version: 0.0.1
# authors: Discourse
# url: TODO
# required_version: 2.7.0

enabled_site_setting :discourse_ai_enabled

require_relative "lib/shared/inference_manager"

require_relative "lib/modules/nsfw/entry_point"
require_relative "lib/modules/toxicity/entry_point"
require_relative "lib/modules/sentiment/entry_point"

after_initialize do
  modules = [
    DiscourseAI::NSFW::EntryPoint.new,
    DiscourseAI::Toxicity::EntryPoint.new,
    DiscourseAI::Sentiment::EntryPoint.new,
  ]

  modules.each do |a_module|
    a_module.load_files
    a_module.inject_into(self)
  end

  module ::DiscourseAI
    PLUGIN_NAME = "discourse-ai"
  end
end
