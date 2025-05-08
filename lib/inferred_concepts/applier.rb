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
      
      # Extracts content from a topic for concept analysis
      # Returns a string with the topic title and first few posts
      def self.topic_content_for_analysis(topic)
        return "" if topic.blank?
        
        # Combine title and first few posts for analysis
        posts = Post.where(topic_id: topic.id).order(:post_number).limit(10)
        
        content = "Title: #{topic.title}\n\n"
        content += posts.map do |p| 
          "#{p.post_number}) #{p.user.username}: #{p.raw}"
        end.join("\n\n")
        
        content
      end
      
      # Comprehensive method to analyze a topic and apply concepts
      def self.analyze_and_apply(topic)
        return if topic.blank?
        
        # Get content to analyze
        content = topic_content_for_analysis(topic)
        
        # Identify concepts
        concept_names = Finder.identify_concepts(content)
        
        # Create or find concepts in the database
        concepts = Finder.create_or_find_concepts(concept_names)
        
        # Apply concepts to the topic
        apply_to_topic(topic, concepts)
        
        concepts
      end
      
      # Match a topic with existing concepts
      def self.match_existing_concepts(topic)
        return [] if topic.blank?
        
        # Get content to analyze
        content = topic_content_for_analysis(topic)
        
        # Get all existing concepts
        existing_concepts = InferredConcept.all.pluck(:name)
        return [] if existing_concepts.empty?
        
        # Use the ConceptMatcher persona to match concepts
        matched_concept_names = match_concepts_to_content(content, existing_concepts)
        
        # Find concepts in the database
        matched_concepts = InferredConcept.where(name: matched_concept_names)
        
        # Apply concepts to the topic
        apply_to_topic(topic, matched_concepts)
        
        matched_concepts
      end
      
      # Use ConceptMatcher persona to match content against provided concepts
      def self.match_concepts_to_content(content, concept_list)
        return [] if content.blank? || concept_list.blank?
        
        # Prepare user message with content and concept list
        user_message = <<~MESSAGE
          Content to analyze:
          #{content}
          
          Available concepts to match:
          #{concept_list.join(", ")}
        MESSAGE
        
        # Use the ConceptMatcher persona to match concepts
        llm = DiscourseAi::Completions::Llm.default_llm
        persona = DiscourseAi::Personas::ConceptMatcher.new
        context = DiscourseAi::Personas::BotContext.new(
          messages: [{ type: :user, content: user_message }],
          user: Discourse.system_user
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