# frozen_string_literal: true

module DiscourseAi
  module InferredConcepts
    class Applier
      # Associates the provided concepts with a topic
      # topic: a Topic instance
      # concepts: an array of InferredConcept instances
      def self.apply_to_topic(topic, concepts)
        return if topic.blank? || concepts.blank?

        concepts.each do |concept|
          # Use the join table to associate the concept with the topic
          # Avoid duplicates by using find_or_create_by
          ActiveRecord::Base.connection.execute(<<~SQL)
            INSERT INTO topics_inferred_concepts (topic_id, inferred_concept_id, created_at, updated_at)
            VALUES (#{topic.id}, #{concept.id}, NOW(), NOW())
            ON CONFLICT (topic_id, inferred_concept_id) DO NOTHING
          SQL
        end
      end

      # Associates the provided concepts with a post
      # post: a Post instance
      # concepts: an array of InferredConcept instances
      def self.apply_to_post(post, concepts)
        return if post.blank? || concepts.blank?

        concepts.each do |concept|
          # Use the join table to associate the concept with the post
          # Avoid duplicates by using find_or_create_by
          ActiveRecord::Base.connection.execute(<<~SQL)
            INSERT INTO posts_inferred_concepts (post_id, inferred_concept_id, created_at, updated_at)
            VALUES (#{post.id}, #{concept.id}, NOW(), NOW())
            ON CONFLICT (post_id, inferred_concept_id) DO NOTHING
          SQL
        end
      end

      # Extracts content from a topic for concept analysis
      # Returns a string with the topic title and first few posts
      def self.topic_content_for_analysis(topic)
        return "" if topic.blank?

        # Combine title and first few posts for analysis
        posts = Post.where(topic_id: topic.id).order(:post_number).limit(10)

        content = "Title: #{topic.title}\n\n"
        content += posts.map { |p| "#{p.post_number}) #{p.user.username}: #{p.raw}" }.join("\n\n")

        content
      end

      # Extracts content from a post for concept analysis
      # Returns a string with the post content
      def self.post_content_for_analysis(post)
        return "" if post.blank?

        # Get the topic title for context
        topic_title = post.topic&.title || ""

        content = "Topic: #{topic_title}\n\n"
        content += "Post by #{post.user.username}:\n#{post.raw}"

        content
      end

      # Match a topic with existing concepts
      def self.match_existing_concepts(topic)
        return [] if topic.blank?

        # Get content to analyze
        content = topic_content_for_analysis(topic)

        # Get all existing concepts
        existing_concepts = DiscourseAi::InferredConcepts::Manager.list_concepts
        return [] if existing_concepts.empty?

        # Use the ConceptMatcher persona to match concepts
        matched_concept_names = match_concepts_to_content(content, existing_concepts)

        # Find concepts in the database
        matched_concepts = InferredConcept.where(name: matched_concept_names)

        # Apply concepts to the topic
        apply_to_topic(topic, matched_concepts)

        matched_concepts
      end

      # Match a post with existing concepts
      def self.match_existing_concepts_for_post(post)
        return [] if post.blank?

        # Get content to analyze
        content = post_content_for_analysis(post)

        # Get all existing concepts
        existing_concepts = DiscourseAi::InferredConcepts::Manager.list_concepts
        return [] if existing_concepts.empty?

        # Use the ConceptMatcher persona to match concepts
        matched_concept_names = match_concepts_to_content(content, existing_concepts)

        # Find concepts in the database
        matched_concepts = InferredConcept.where(name: matched_concept_names)

        # Apply concepts to the post
        apply_to_post(post, matched_concepts)

        matched_concepts
      end

      # Use ConceptMatcher persona to match content against provided concepts
      def self.match_concepts_to_content(content, concept_list)
        return [] if content.blank? || concept_list.blank?

        # Prepare user message with only the content
        user_message = content

        # Use the ConceptMatcher persona to match concepts
        llm = DiscourseAi::Completions::Llm.default_llm
        persona = DiscourseAi::Personas::ConceptMatcher.new
        context =
          DiscourseAi::Personas::BotContext.new(
            messages: [{ type: :user, content: user_message }],
            user: Discourse.system_user,
            inferred_concepts: DiscourseAi::InferredConcepts::Manager.list_concepts,
          )

        prompt = persona.craft_prompt(context)
        response = llm.completion(prompt, extract_json: true)

        return [] unless response.success?

        matching_concepts = response.parsed_output["matching_concepts"]
        matching_concepts || []
      end
    end
  end
end
