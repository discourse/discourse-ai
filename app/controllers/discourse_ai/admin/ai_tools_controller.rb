# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiToolsController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      before_action :find_ai_tool, only: %i[show update destroy]

      def index
        ai_tools = AiTool.all.map { |tool| AiCustomToolSerializer.new(tool, root: false) }
        render json: { ai_tools: ai_tools }
      end

      def show
        render json: AiCustomToolSerializer.new(@ai_tool)
      end

      def create
        ai_tool = AiTool.new(ai_tool_params)
        ai_tool.created_by_id = current_user.id

        if ai_tool.save
          render json: AiCustomToolSerializer.new(ai_tool), status: :created
        else
          render_json_error ai_tool
        end
      end

      def update
        if @ai_tool.update(ai_tool_params)
          render json: AiCustomToolSerializer.new(@ai_tool)
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

      private

      def find_ai_tool
        @ai_tool = AiTool.find(params[:id])
      end

      def ai_tool_params
        params.require(:ai_tool).permit(
          :name,
          :description,
          :script,
          parameters: %i[name type description],
        )
      end
    end
  end
end
