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
  # Using extension maintainer's recommendation for ivfflat indexes
  # Results are not as good as without indexes, but it's much faster
  # Disk usage is ~1x the size of the table, so this doubles table total size
  count = Topic.count
  lists = count < 1_000_000 ? count / 1000 : Math.sqrt(count).to_i
  probes = count < 1_000_000 ? lists / 10 : Math.sqrt(lists).to_i

  vector_representation_klass = DiscourseAi::Embeddings::Vectors::Base.find_vector_representation
  strategy = DiscourseAi::Embeddings::Strategies::Truncation.new

  DB.exec("SET work_mem TO '#{args[:work_mem] || "1GB"}';")
  vector_representation_klass.new(strategy).create_index(lists, probes)
  DB.exec("RESET work_mem;")
  DB.exec("SET ivfflat.probes = #{probes};")
end
