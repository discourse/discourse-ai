# frozen_string_literal: true

desc "Backfill embeddings for all topics and posts"
task "ai:embeddings:backfill" => [:environment] do
  public_categories = Category.where(read_restricted: false).pluck(:id)

  strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
  vector_rep = DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)
  table_name = vector_rep.topic_table_name

  Topic
    .joins("LEFT JOIN #{table_name} ON #{table_name}.topic_id = topics.id")
    .where("#{table_name}.topic_id IS NULL")
    .where("category_id IN (?)", public_categories)
    .where(deleted_at: nil)
    .order("topics.id DESC")
    .find_each do |t|
      print "."
      vector_rep.generate_representation_from(t)
    end

  table_name = vector_rep.post_table_name
  Post
    .joins("LEFT JOIN #{table_name} ON #{table_name}.post_id = posts.id")
    .where("#{table_name}.post_id IS NULL")
    .where(deleted_at: nil)
    .order("posts.id DESC")
    .find_each do |t|
      print "."
      vector_rep.generate_representation_from(t)
    end
end

desc "Creates indexes for embeddings"
task "ai:embeddings:index", [:work_mem] => [:environment] do |_, args|
  strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
  vector_rep = DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)

  vector_rep.consider_indexing(memory: args[:work_mem] || "100MB")
end
