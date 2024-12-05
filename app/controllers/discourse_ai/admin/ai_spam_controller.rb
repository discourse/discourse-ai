# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiSpamController < ::Admin::AdminController
      requires_plugin "discourse-ai"

      def show
        render json: AiSpamSerializer.new({}, root: false)
      end
    end
  end
end
