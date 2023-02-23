# frozen_string_literal: true

module DiscourseAI
  module NSFW
    class EntryPoint
      def inject_into(plugin)
        require_relative "evaluation.rb"
        require_relative "../../../app/jobs/regular/modules/nsfw/evaluate_content.rb"

        plugin.add_model_callback(Upload, :after_create) do
          Jobs.enqueue(:evaluate_content, upload_id: self.id)
        end
      end
    end
  end
end
