# frozen_string_literal: true

module Jobs
  class ApplyInferredConcepts < ::Jobs::Base
    sidekiq_options queue: 'low'

    # Process a batch of topics to apply existing concepts to them
    #
    # @param args [Hash] Contains job arguments
    # @option args [Array<Integer>] :topic_ids Required - List of topic IDs to process
    # @option args [Integer] :batch_size (100) Number of topics to process in each batch
    def execute(args = {})
      return if args[:topic_ids].blank?
      
      # Process topics in smaller batches to avoid memory issues
      batch_size = args[:batch_size] || 100
      
      # Get the list of topic IDs
      topic_ids = args[:topic_ids]
      
      # Process topics in batches
      topic_ids.each_slice(batch_size) do |batch_topic_ids|
        process_batch(batch_topic_ids)
      end
    end
    
    private
    
    def process_batch(topic_ids)
      topics = Topic.where(id: topic_ids)
      
      topics.each do |topic|
        begin
          process_topic(topic)
        rescue => e
          Rails.logger.error("Error applying concepts to topic #{topic.id}: #{e.message}\n#{e.backtrace.join("\n")}")
        end
      end
    end
    
    def process_topic(topic)
      # Match topic against existing concepts and apply them
      # Pass the topic object directly
      DiscourseAi::InferredConcepts::Manager.match_topic_to_concepts(topic)
    end
  end
end