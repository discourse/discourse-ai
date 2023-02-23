# frozen_string_literal: true

module Jobs
  class EvaluateContent < ::Jobs::Base
    def execute(args)
      upload = Upload.find_by_id(args[:upload_id])

      return unless upload

      result = DiscourseAI::NSFW::Evaluation.new.perform(upload)

      # FIXME(roman): This is a simplistic action just to create
      # the basic flow. We'll introduce flagging capabilities in the future.
      upload.destroy! if result[:verdict]
    end
  end
end
