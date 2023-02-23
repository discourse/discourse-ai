# frozen_string_literal: true
module DiscourseAI
  module Toxicity
    class EntryPoint
      def inject_into(plugin)
        require_relative "event_handler.rb"
        require_relative "classifier.rb"
        require_relative "post_classifier.rb"
        require_relative "chat_message_classifier.rb"

        jobs_base_path = "../../../app/jobs/regular/modules/toxicity"

        require_relative "#{jobs_base_path}/toxicity_classify_post.rb"
        require_relative "#{jobs_base_path}/toxicity_classify_chat_message.rb"

        plugin.on(:post_created) do |post|
          DiscourseAI::Toxicity::EventHandler.handle_post_async(post)
        end

        plugin.on(:post_edited) do |post|
          DiscourseAI::Toxicity::EventHandler.handle_post_async(post)
        end

        plugin.on(:chat_message_created) do |chat_message|
          DiscourseAI::Toxicity::EventHandler.handle_chat_async(chat_message)
        end

        plugin.on(:chat_message_edited) do |chat_message|
          DiscourseAI::Toxicity::EventHandler.handle_chat_async(chat_message)
        end
      end
    end
  end
end
