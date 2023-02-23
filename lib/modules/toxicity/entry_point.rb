# frozen_string_literal: true
module DiscourseAI
  module Toxicity
    class EntryPoint
      def load_files
        require_relative "event_handler.rb"
        require_relative "classifier.rb"
        require_relative "post_classifier.rb"
        require_relative "chat_message_classifier.rb"

        require_relative "jobs/regular/toxicity_classify_post.rb"
        require_relative "jobs/regular/toxicity_classify_chat_message.rb"
      end

      def inject_into(plugin)
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
