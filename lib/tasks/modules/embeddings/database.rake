# frozen_string_literal: true

desc "Backfill embeddings for all topics"
task "ai:embeddings:backfill", [:start_topic] => [:environment] do |_, args|
  public_categories = Category.where(read_restricted: false).pluck(:id)

  strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
  vector_rep = DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)
  table_name = vector_rep.table_name

  Topic
    .joins("LEFT JOIN #{table_name} ON #{table_name}.topic_id = topics.id")
    .where("#{table_name}.topic_id IS NULL")
    .where("topics.id >= ?", args[:start_topic].to_i || 0)
    .where("category_id IN (?)", public_categories)
    .where(deleted_at: nil)
    .order("topics.id ASC")
    .find_each do |t|
      print "."
      vector_rep.generate_topic_representation_from(t)
    end
end

desc "Creates indexes for embeddings"
task "ai:embeddings:index", [:work_mem] => [:environment] do |_, args|
  strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
  vector_rep = DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)

  vector_rep.create_index(memory: args[:work_mem] || "100MB")
end
