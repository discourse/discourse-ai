# frozen_string_literal: true

module ::DiscourseAi
  module Database
    class Connection
      def self.connect!
        pg_conn = PG.connect(SiteSetting.ai_embeddings_pg_connection_string)
        @@db = MiniSql::Connection.get(pg_conn)
      end

      def self.db
        @@db ||= connect!
      end
    end
  end
end
