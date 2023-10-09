# frozen_string_literal: true

module DiscourseAi
  module Completions
    class EntryPoint
      def load_files
        require_relative "dialects/chat_gpt"
        require_relative "dialects/llama2_classic"
        require_relative "dialects/orca_style"
        require_relative "dialects/claude"

        require_relative "endpoints/canned_response"
        require_relative "endpoints/base"
        require_relative "endpoints/anthropic"
        require_relative "endpoints/aws_bedrock"
        require_relative "endpoints/open_ai"
        require_relative "endpoints/hugging_face"

        require_relative "llm"
      end

      def inject_into(_)
      end
    end
  end
end
