# frozen_string_literal: true

module DiscourseAi
  module InferredConcepts
    class Manager
      # Generate new concepts for a topic and apply them
      # @param topic [Topic] A Topic instance
      # @return [Array<InferredConcept>] The concepts that were applied
      def self.analyze_topic(topic)
        return [] if topic.blank?
        
        Applier.analyze_and_apply(topic)
      end
      
      # Extract new concepts from arbitrary content
      # @param content [String] The content to analyze
      # @return [Array<String>] The identified concept names
      def self.identify_concepts(content)
        Finder.identify_concepts(content)
      end
      
      # Identify and create concepts from content without applying them to any topic
      # @param content [String] The content to analyze
      # @return [Array<InferredConcept>] The created or found concepts
      def self.generate_concepts_from_content(content)
        return [] if content.blank?
        
        # Identify concepts
        concept_names = Finder.identify_concepts(content)
        return [] if concept_names.blank?
        
        # Create or find concepts in the database
        Finder.create_or_find_concepts(concept_names)
      end
      
      # Generate concepts from a topic's content without applying them to the topic
      # @param topic [Topic] A Topic instance
      # @return [Array<InferredConcept>] The created or found concepts
      def self.generate_concepts_from_topic(topic)
        return [] if topic.blank?
        
        # Get content to analyze
        content = Applier.topic_content_for_analysis(topic)
        return [] if content.blank?
        
        # Generate concepts from the content
        generate_concepts_from_content(content)
      end
      
      # Match a topic against existing concepts
      # @param topic [Topic] A Topic instance
      # @return [Array<InferredConcept>] The concepts that were applied
      def self.match_topic_to_concepts(topic)
        return [] if topic.blank?
        
        Applier.match_existing_concepts(topic)
      end
      
      # Find topics that have a specific concept
      # @param concept_name [String] The name of the concept to search for
      # @return [Array<Topic>] Topics that have the specified concept
      def self.search_topics_by_concept(concept_name)
        concept = ::InferredConcept.find_by(name: concept_name)
        return [] unless concept
        concept.topics
      end
      
      # Match arbitrary content against existing concepts
      # @param content [String] The content to analyze
      # @return [Array<String>] Names of matching concepts
      def self.match_content_to_concepts(content)
        existing_concepts = InferredConcept.all.pluck(:name)
        return [] if existing_concepts.empty?
        
        Applier.match_concepts_to_content(content, existing_concepts)
      end
      
      # Find candidate topics that are good for concept generation
      # 
      # @param opts [Hash] Options to pass to the finder
      # @option opts [Integer] :limit (100) Maximum number of topics to return
      # @option opts [Integer] :min_posts (5) Minimum number of posts in topic
      # @option opts [Integer] :min_likes (10) Minimum number of likes across all posts
      # @option opts [Integer] :min_views (100) Minimum number of views
      # @option opts [Array<Integer>] :exclude_topic_ids ([]) Topic IDs to exclude
      # @option opts [Array<Integer>] :category_ids (nil) Only include topics from these categories
      # @option opts [DateTime] :created_after (30.days.ago) Only include topics created after this time
      # @return [Array<Topic>] Array of Topic objects that are good candidates
      def self.find_candidate_topics(opts = {})
        Finder.find_candidate_topics(opts)
      end
    end
  end
end