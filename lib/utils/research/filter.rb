# frozen_string_literal: true

module DiscourseAi
  module Utils
    module Research
      class Filter
        # Stores custom filter handlers
        def self.register_filter(matcher, &block)
          (@registered_filters ||= {})[matcher] = block
        end

        def self.registered_filters
          @registered_filters ||= {}
        end

        def self.word_to_date(str)
          ::Search.word_to_date(str)
        end

        attr_reader :term, :filters, :order, :guardian, :limit, :offset

        # Define all filters at class level
        register_filter(/\Astatus:open\z/i) do |relation, _, _|
          relation.where("topics.closed = false AND topics.archived = false")
        end

        register_filter(/\Astatus:closed\z/i) do |relation, _, _|
          relation.where("topics.closed = true")
        end

        register_filter(/\Astatus:archived\z/i) do |relation, _, _|
          relation.where("topics.archived = true")
        end

        register_filter(/\Astatus:noreplies\z/i) do |relation, _, _|
          relation.where("topics.posts_count = 1")
        end

        register_filter(/\Astatus:single_user\z/i) do |relation, _, _|
          relation.where("topics.participant_count = 1")
        end

        # Date filters
        register_filter(/\Abefore:(.*)\z/i) do |relation, date_str, _|
          if date = Filter.word_to_date(date_str)
            relation.where("posts.created_at < ?", date)
          else
            relation
          end
        end

        register_filter(/\Aafter:(.*)\z/i) do |relation, date_str, _|
          if date = Filter.word_to_date(date_str)
            relation.where("posts.created_at > ?", date)
          else
            relation
          end
        end

        # Category filter
        register_filter(/\Acategory:([a-zA-Z0-9_\-]+)\z/i) do |relation, slug, _|
          category = Category.find_by("LOWER(slug) = LOWER(?)", slug)
          if category
            category_ids = [category.id]
            category_ids +=
              Category.subcategory_ids(category.id) if category.subcategory_ids.present?
            relation.where("topics.category_id IN (?)", category_ids)
          else
            relation.where("1 = 0") # No results if category doesn't exist
          end
        end

        # Tag filter
        register_filter(/\Atag:([a-zA-Z0-9_\-]+)\z/i) do |relation, name, _|
          tag = Tag.find_by_name(name)
          if tag
            relation.joins("INNER JOIN topic_tags ON topic_tags.topic_id = topics.id").where(
              "topic_tags.tag_id = ?",
              tag.id,
            )
          else
            relation.where("1 = 0") # No results if tag doesn't exist
          end
        end

        # User filter
        register_filter(/\A\@(\w+)\z/i) do |relation, username, filter|
          user = User.find_by(username_lower: username.downcase)
          if user
            relation.where("posts.user_id = ?", user.id)
          else
            relation.where("1 = 0") # No results if user doesn't exist
          end
        end

        # Posted by current user
        register_filter(/\Ain:posted\z/i) do |relation, _, filter|
          if filter.guardian.user
            relation.where("posts.user_id = ?", filter.guardian.user.id)
          else
            relation.where("1 = 0") # No results if not logged in
          end
        end

        register_filter(/\Agroup:([a-zA-Z0-9_\-]+)\z/i) do |relation, name, filter|
          group = Group.find_by("name ILIKE ?", name)
          if group
            relation.where(
              "posts.user_id IN (
              SELECT gu.user_id FROM group_users gu
              WHERE gu.group_id = ?
            )",
              group.id,
            )
          else
            relation.where("1 = 0") # No results if group doesn't exist
          end
        end

        def initialize(term, guardian: nil, limit: nil, offset: nil)
          @term = term.to_s
          @guardian = guardian || Guardian.new
          @limit = limit
          @offset = offset
          @filters = []
          @valid = true

          @term = process_filters(@term)
        end

        def search
          filtered = Post.secured(@guardian).joins(:topic).merge(Topic.secured(@guardian))

          @filters.each do |filter_block, match_data|
            filtered = filter_block.call(filtered, match_data, self)
          end

          filtered = filtered.limit(@limit) if @limit.to_i > 0
          filtered = filtered.offset(@offset) if @offset.to_i > 0

          filtered
        end

        private

        def process_filters(term)
          return "" if term.blank?

          term
            .to_s
            .scan(/(([^" \t\n\x0B\f\r]+)?(("[^"]+")?))/)
            .to_a
            .map do |(word, _)|
              next if word.blank?

              # Check for order:xxx syntax
              if word =~ /\Aorder:(\w+)\z/i
                @order = $1.downcase.to_sym
                next nil
              end

              # Check registered filters
              found = false
              self.class.registered_filters.each do |matcher, block|
                if word =~ matcher
                  @filters << [block, $1]
                  found = true
                  break
                end
              end

              found ? nil : word
            end
            .compact
            .join(" ")
        end
      end
    end
  end
end
