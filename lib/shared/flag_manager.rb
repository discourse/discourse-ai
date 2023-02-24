# frozen_string_literal: true

module ::DiscourseAI
  class FlagManager
    DEFAULT_FLAGGER = Discourse.system_user
    DEFAULT_REASON = "discourse-ai"

    def initialize(object, flagger: DEFAULT_FLAGGER, type: :inappropriate, reasons: DEFAULT_REASON)
      @flagger = flagger
      @object = object
      @type = type
      @reasons = reasons
    end

    def flag!
      PostActionCreator.new(
        @flagger,
        @object,
        PostActionType.types[:inappropriate],
        reason: @reasons,
        queue_for_review: true,
      ).perform

      @object.publish_change_to_clients! :acted
    end
  end
end
