# frozen_string_literal: true

module DiscourseAi
  module Utils
    class AiStaffActionLogger
      def initialize(current_user)
        @current_user = current_user
        @staff_logger = ::StaffActionLogger.new(current_user)
      end

      # Log creation of an AI entity (LLM model or persona)
      def log_creation(entity_type, entity, attributes_to_log)
        log_details = extract_entity_attributes(entity, attributes_to_log)
        
        @staff_logger.log_custom("create_ai_#{entity_type}", log_details)
      end

      # Log update of an AI entity with before/after comparison
      def log_update(entity_type, entity, initial_attributes, trackable_fields, json_fields = [])
        current_attributes = entity.attributes
        changes = {}

        # Track changes to standard fields
        trackable_fields.each do |field|
          initial_value = initial_attributes[field]
          current_value = current_attributes[field]
          
          if initial_value != current_value
            # For large text fields, don't show the entire content
            if should_simplify_field?(field, initial_value, current_value)
              changes[field] = "updated"
            else
              changes[field] = "#{initial_value} → #{current_value}"
            end
          end
        end

        # Track changes to arrays and JSON fields
        json_fields.each do |field|
          if initial_attributes[field].to_s != current_attributes[field].to_s
            changes[field] = "updated"
          end
        end

        # Only log if there are actual changes
        if changes.any?
          log_details = entity_identifier(entity, entity_type).merge(changes)
          @staff_logger.log_custom("update_ai_#{entity_type}", log_details)
        end
      end

      # Log deletion of an AI entity
      def log_deletion(entity_type, entity_details)
        @staff_logger.log_custom("delete_ai_#{entity_type}", entity_details)
      end
      
      # Direct custom logging for complex cases
      def log_custom(action_type, log_details)
        @staff_logger.log_custom(action_type, log_details)
      end

      private

      def extract_entity_attributes(entity, attributes_to_log)
        result = {}
        
        attributes_to_log.each do |attr|
          value = entity.public_send(attr)
          
          # Handle large text fields
          if attr == :system_prompt && value.is_a?(String) && value.length > 100
            result[attr] = value.truncate(100)
          else
            result[attr] = value
          end
        end
        
        result
      end

      def should_simplify_field?(field, initial_value, current_value)
        # For large text fields, or sensitive data, don't show the entire content
        return true if field == "system_prompt" && 
                       initial_value.present? && 
                       current_value.present? && 
                       (initial_value.length > 100 || current_value.length > 100)
        
        return true if field.include?("api_key") || field.include?("secret") || field.include?("password")
        
        false
      end

      def entity_identifier(entity, entity_type)
        case entity_type
        when "llm_model"
          {
            model_id: entity.id,
            model_name: entity.name,
            display_name: entity.display_name
          }
        when "persona"
          {
            persona_id: entity.id,
            persona_name: entity.name
          }
        else
          { id: entity.id }
        end
      end
    end
  end
end