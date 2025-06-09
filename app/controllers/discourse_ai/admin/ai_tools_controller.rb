# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiToolsController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      before_action :find_ai_tool, only: %i[test edit update destroy]

      def index
        ai_tools = AiTool.all
        render_serialized({ ai_tools: ai_tools }, AiCustomToolListSerializer, root: false)
      end

      def new
      end

      def edit
        render_serialized(@ai_tool, AiCustomToolSerializer)
      end

      def create
        ai_tool = AiTool.new(ai_tool_params)
        ai_tool.created_by_id = current_user.id

        if ai_tool.save
          RagDocumentFragment.link_target_and_uploads(ai_tool, attached_upload_ids)
          log_ai_tool_creation(ai_tool)
          render_serialized(ai_tool, AiCustomToolSerializer, status: :created)
        else
          render_json_error ai_tool
        end
      end

      def update
        # Capture initial state for logging
        initial_attributes = @ai_tool.attributes.dup
        
        if @ai_tool.update(ai_tool_params)
          RagDocumentFragment.update_target_uploads(@ai_tool, attached_upload_ids)
          log_ai_tool_update(@ai_tool, initial_attributes)
          render_serialized(@ai_tool, AiCustomToolSerializer)
        else
          render_json_error @ai_tool
        end
      end

      def destroy
        # Capture tool details for logging before destruction
        tool_details = {
          tool_id: @ai_tool.id,
          name: @ai_tool.name,
          tool_name: @ai_tool.tool_name
        }

        if @ai_tool.destroy
          log_ai_tool_deletion(tool_details)
          head :no_content
        else
          render_json_error @ai_tool
        end
      end

      def test
        @ai_tool.assign_attributes(ai_tool_params) if params[:ai_tool]
        parameters = params[:parameters].to_unsafe_h

        # we need an llm so we have a tokenizer
        # but will do without if none is available
        llm = LlmModel.first&.to_llm
        runner = @ai_tool.runner(parameters, llm: llm, bot_user: current_user)
        result = runner.invoke

        if result.is_a?(Hash) && result[:error]
          render_json_error result[:error]
        else
          render json: { output: result }
        end
      rescue ActiveRecord::RecordNotFound => e
        render_json_error e.message, status: 400
      rescue => e
        render_json_error "Error executing the tool: #{e.message}", status: 400
      end

      private

      def attached_upload_ids
        params[:ai_tool][:rag_uploads].to_a.map { |h| h[:id] }
      end

      def find_ai_tool
        @ai_tool = AiTool.find(params[:id].to_i)
      end

      def ai_tool_params
        params
          .require(:ai_tool)
          .permit(
            :name,
            :tool_name,
            :description,
            :script,
            :summary,
            :rag_chunk_tokens,
            :rag_chunk_overlap_tokens,
            :rag_llm_model_id,
            rag_uploads: [:id],
            parameters: [:name, :type, :description, :required, enum: []],
          )
          .except(:rag_uploads)
      end
      
      def log_ai_tool_creation(ai_tool)
        # Create log details
        log_details = {
          tool_id: ai_tool.id,
          name: ai_tool.name,
          tool_name: ai_tool.tool_name,
          description: ai_tool.description
        }
        
        # Add parameter count if available
        if ai_tool.parameters.present?
          log_details[:parameter_count] = ai_tool.parameters.size
        end
        
        # For sensitive/large fields, don't include the full content
        if ai_tool.script.present?
          log_details[:script_size] = ai_tool.script.size
        end
        
        # Log the action
        StaffActionLogger.new(current_user).log_custom("create_ai_tool", log_details)
      end
      
      def log_ai_tool_update(ai_tool, initial_attributes)
        # Create log details
        log_details = {
          tool_id: ai_tool.id,
          name: ai_tool.name,
          tool_name: ai_tool.tool_name
        }
        
        # Track changes in fields
        changed_fields = []
        
        # Check for changes in basic fields
        %w[name tool_name description summary enabled].each do |field|
          if initial_attributes[field] != ai_tool.attributes[field]
            changed_fields << field
            log_details["#{field}_changed"] = true
          end
        end
        
        # Special handling for script (sensitive/large)
        if initial_attributes['script'] != ai_tool.script
          changed_fields << 'script'
          log_details[:script_changed] = true
        end
        
        # Special handling for parameters (JSON)
        if initial_attributes['parameters'].to_s != ai_tool.parameters.to_s
          changed_fields << 'parameters'
          log_details[:parameters_changed] = true
        end
        
        # Only log if there are actual changes
        if changed_fields.any?
          log_details[:changed_fields] = changed_fields
          StaffActionLogger.new(current_user).log_custom("update_ai_tool", log_details)
        end
      end
      
      def log_ai_tool_deletion(tool_details)
        StaffActionLogger.new(current_user).log_custom("delete_ai_tool", tool_details)
      end
    end
  end
end
