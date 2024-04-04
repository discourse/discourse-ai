# frozen_string_literal: true

module ::Jobs
  class GenerateRagEmbeddings < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      return if (fragments = RagDocumentFragment.where(id: args[:fragment_ids].to_a)).empty?

      truncation = DiscourseAi::Embeddings::Strategies::Truncation.new
      vector_rep =
        DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(truncation)

      # generate_representation_from checks compares the digest value to make sure
      # the embedding is only generated once per fragment unless something changes.
      fragments.map { |fragment| vector_rep.generate_representation_from(fragment) }
    end
  end
end
