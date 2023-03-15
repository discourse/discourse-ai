# frozen_string_literal: true

desc "Creates tables to store embeddings"
task "ai:embeddings:create_table" => [:environment] do
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
      puts "."
      DiscourseAI::Embeddings::Topic.new(t).perform!
    end
end

desc "Creates indexes for embeddings"
task "ai:embeddings:index" => [:environment] do
  DiscourseAi::Embeddings::Models.enabled_models.each do |model|
    DiscourseAi::Database::Connection.db.exec(<<~SQL)
      CREATE INDEX IF NOT EXISTS
        topic_embeddings_#{model.name.underscore}_search
      ON
        topic_embeddings_#{model.name.underscore}
      USING
        ivfflat (embedding #{DiscourseAi::Embeddings::Models::SEARCH_FUNCTION_TO_PG_INDEX[model.functions.first]});
    SQL
  end
end
