# frozen_string_literal: true

desc "Backfill embeddings for all topics"
task "ai:embeddings:backfill", [:start_topic] => [:environment] do |_, args|
  public_categories = Category.where(read_restricted: false).pluck(:id)
  manager = DiscourseAi::Embeddings::Manager.new(Topic.first)
  Topic
    .joins("LEFT JOIN #{manager.topic_embeddings_table} ON #{manager.topic_embeddings_table}.topic_id = topics.id")
    .where("#{manager.topic_embeddings_table}.topic_id IS NULL")
    .where("topics.id >= ?", args[:start_topic].to_i || 0)
    .where("category_id IN (?)", public_categories)
    .where(deleted_at: nil)
    .order('topics.id ASC')
    .find_each do |t|
      print "."
      DiscourseAi::Embeddings::Manager.new(t).generate!
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

  manager = DiscourseAi::Embeddings::Manager.new(Topic.first)
  table = manager.topic_embeddings_table
  index = "#{table}_search"

  DB.exec("SET work_mem TO '#{args[:work_mem] || "1GB"}';")
  DB.exec(<<~SQL)
    DROP INDEX IF EXISTS #{index};
    CREATE INDEX IF NOT EXISTS
      #{index}
    ON
      #{table}
    USING
      ivfflat (embeddings #{manager.model.pg_index_type})
    WITH
      (lists = #{lists})
    WHERE
      model_version = #{manager.model.version} AND
      strategy_version = #{manager.strategy.version};
  SQL
  DB.exec("RESET work_mem;")
  DB.exec("SET ivfflat.probes = #{probes};")
end
