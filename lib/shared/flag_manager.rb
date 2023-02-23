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
      PostActionCreator.create(@flagger, @object, :inappropriate, reason: @reasons)
      @object.publish_change_to_clients! :acted
    end
  end
end
