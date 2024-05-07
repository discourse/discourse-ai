#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Tools
      class Read < Tool
        def self.signature
          {
            name: name,
            description: "Will read a topic or a post on this Discourse instance",
            parameters: [
              {
                name: "topic_id",
                description: "the id of the topic to read",
                type: "integer",
                required: true,
              },
              {
                name: "post_number",
                description: "the post number to read",
                type: "integer",
                required: true,
              },
            ],
          }
        end

        def self.name
          "read"
        end

        attr_reader :title, :url

        def topic_id
          parameters[:topic_id]
        end

        def post_number
          parameters[:post_number]
        end

        def invoke
          not_found = { topic_id: topic_id, description: "Topic not found" }

          @title = ""

          topic = Topic.find_by(id: topic_id.to_i)
          return not_found if !topic || !Guardian.new.can_see?(topic)

          @title = topic.title

          posts = Post.secured(Guardian.new).where(topic_id: topic_id).order(:post_number).limit(40)
          @url = topic.relative_url(post_number)

          posts = posts.where("post_number = ?", post_number) if post_number

          content = +<<~TEXT.strip
          title: #{topic.title}
          TEXT

          category_names = [
            topic.category&.parent_category&.name,
            topic.category&.name,
          ].compact.join(" ")
          content << "\ncategories: #{category_names}" if category_names.present?

          if topic.tags.length > 0
            tags = DiscourseTagging.filter_visible(topic.tags, Guardian.new)
            content << "\ntags: #{tags.map(&:name).join(", ")}\n\n" if tags.length > 0
          end

          posts.each { |post| content << "\n\n#{post.username} said:\n\n#{post.raw}" }

          # TODO: 16k or 100k models can handle a lot more tokens
          content = llm.tokenizer.truncate(content, 1500).squish

          result = { topic_id: topic_id, content: content, complete: true }
          result[:post_number] = post_number if post_number
          result
        end

        protected

        def description_args
          { title: title, url: url }
        end
      end
    end
  end
end
