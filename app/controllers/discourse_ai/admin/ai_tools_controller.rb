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
          render_serialized(ai_tool, AiCustomToolSerializer, status: :created)
        else
          render_json_error ai_tool
        end
      end

      def update
        if @ai_tool.update(ai_tool_params)
          RagDocumentFragment.update_target_uploads(@ai_tool, attached_upload_ids)
          render_serialized(@ai_tool, AiCustomToolSerializer)
        else
          render_json_error @ai_tool
        end
      end

      def destroy
        if @ai_tool.destroy
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
    end
  end
end
