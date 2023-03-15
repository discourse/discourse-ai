desc "Creates tables to store embeddings"
task "ai:embeddings:prepare" => [:environment] do
  DiscourseAi::Embeddings::Model.enabled_models.each do |model|
    DiscourseAi::Database::Connection.db.exec(<<~SQL)
        CREATE TABLE IF NOT EXISTS topic_embeddings_#{model.name.underscore} (
          topic_id bigint PRIMARY KEY,
          embedding vector(#{model.dimensions})
        );
        CREATE INDEX ON topic_embeddings_#{model.name.underscore} USING ivfflat (embedding vector_#{model.functions.first == :dot ? "ip" : "cosine"}_ops);
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
      puts '.'
      DiscourseAI::Embeddings::Topic.new(t).perform!
    end
end
