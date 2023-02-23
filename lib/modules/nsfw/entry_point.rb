# frozen_string_literal: true

module DiscourseAI
  module NSFW
    class EntryPoint
      def load_files
        require_relative "evaluation.rb"
        require_relative "jobs/regular/evaluate_content.rb"
      end

      def inject_into(plugin)
        plugin.add_model_callback(Upload, :after_create) do
          Jobs.enqueue(:evaluate_content, upload_id: self.id)
        end
      end
    end
  end
end
