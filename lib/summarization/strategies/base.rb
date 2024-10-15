# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      # Objects inheriting from this class will get passed as a dependency to `DiscourseAi::Summarization::FoldContent`.
      # This collaborator knows how to source the content to summarize and the prompts used in the process,
      # one for summarizing a chunk and another for concatenating them if necessary.
      class Base
        def initialize(target)
          @target = target
        end

        attr_reader :target

        # The summary type differentiates instances of `AiSummary` pointing to a single target.
        # See the `summary_type` enum for available options.
        def type
          raise NotImplementedError
        end

        # @returns { Hash } - Content to summarize.
        #
        # This method returns a hash with the content to summarize and additional information.
        # The only mandatory key is `contents`, which must be an array of hashes with
        # the following structure:
        #
        # {
        #  poster: A way to tell who write the content,
        #  id: A number to signal order,
        #  text: Text to summarize
        # }
        #
        # Additionally, you could add more context, which will be available in the prompt. e.g.:
        #
        # {
        #   resource_path: "#{Discourse.base_path}/t/-/#{target.id}",
        #   content_title: target.title,
        #   contents: [...]
        # }
        #
        def targets_data
          raise NotImplementedError
        end

        # @returns { DiscourseAi::Completions::Prompt } - Prompt passed to the LLM when concatenating multiple chunks.
        def contatenation_prompt(_texts_to_summarize)
          raise NotImplementedError
        end

        # @returns { DiscourseAi::Completions::Prompt } - Prompt passed to the LLM on each chunk,
        # and when the whole content fits in one call.
        def summarize_single_prompt(_input, _opts)
          raise NotImplementedError
        end
      end
    end
  end
end
