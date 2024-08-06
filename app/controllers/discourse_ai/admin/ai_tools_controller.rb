# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiToolsController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      before_action :find_ai_tool, only: %i[show update destroy]

      def index
        ai_tools = AiTool.all
        render_serialized({ ai_tools: ai_tools }, AiCustomToolListSerializer, root: false)
      end

      def show
        render_serialized(@ai_tool, AiCustomToolSerializer)
      end

      def create
        ai_tool = AiTool.new(ai_tool_params)
        ai_tool.created_by_id = current_user.id

        if ai_tool.save
          render_serialized(ai_tool, AiCustomToolSerializer, status: :created)
        else
          render_json_error ai_tool
        end
      end

      def update
        if @ai_tool.update(ai_tool_params)
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
        if params[:id].present?
          ai_tool = AiTool.find(params[:id])
        else
          ai_tool = AiTool.new(ai_tool_params)
        end

        parameters = params[:parameters].to_unsafe_h

        # we need an llm so we have a tokenizer
        # but will do without if none is available
        llm = LlmModel.first&.to_llm
        runner = ai_tool.runner(parameters, llm: llm, bot_user: current_user, context: {})
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

      def find_ai_tool
        @ai_tool = AiTool.find(params[:id])
      end

      def ai_tool_params
        params.require(:ai_tool).permit(
          :name,
          :description,
          :script,
          :summary,
          parameters: [:name, :type, :description, :required, enum: []],
        )
      end
    end
  end
end
