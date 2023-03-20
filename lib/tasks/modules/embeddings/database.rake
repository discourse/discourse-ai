# frozen_string_literal: true

desc "Creates tables to store embeddings"
task "ai:embeddings:create_table" => [:environment] do
  DiscourseAi::Database::Connection.db.exec(<<~SQL)
    CREATE EXTENSION IF NOT EXISTS pg_vector;
  SQL

  DiscourseAi::Embeddings::Models.enabled_models.each do |model|
    DiscourseAi::Database::Connection.db.exec(<<~SQL)
        CREATE TABLE IF NOT EXISTS topic_embeddings_#{model.name.underscore} (
          topic_id bigint PRIMARY KEY,
          embedding vector(#{model.dimensions})
        );
      SQL
  end
end

desc "Backfill embeddings for all topics"
task "ai:embeddings:backfill" => [:environment] do
  public_categories = Category.where(read_restricted: false).pluck(:id)
  Topic
    .where("category_id IN ?", public_categories)
    .where(deleted_at: nil)
    .find_each do |t|
      print "."
      DiscourseAI::Embeddings::Topic.new(t).perform!
    end
end

desc "Creates indexes for embeddings"
task "ai:embeddings:index", [:work_mem] => [:environment] do |_, args|
  # Using 4 * sqrt(number of topics) as a rule of thumb for now
  # Results are not as good as without indexes, but it's much faster
  # Disk usage is ~1x the size of the table, so this double table total size
  lists = 4 * Math.sqrt(Topic.count).to_i

  DiscourseAi::Database::Connection.db.exec("SET work_mem TO '#{args[:work_mem] || "1GB"}';")
  DiscourseAi::Embeddings::Models.enabled_models.each do |model|
    DiscourseAi::Database::Connection.db.exec(<<~SQL)
      CREATE INDEX IF NOT EXISTS
        topic_embeddings_#{model.name.underscore}_search
      ON
        topic_embeddings_#{model.name.underscore}
      USING
        ivfflat (embedding #{DiscourseAi::Embeddings::Models::SEARCH_FUNCTION_TO_PG_INDEX[model.functions.first]})
      WITH
        (lists = #{lists});
    SQL
    DiscourseAi::Database::Connection.db.exec("RESET work_mem;")
  end
end
