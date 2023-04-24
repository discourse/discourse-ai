# frozen_string_literal: true

class AiApiAuditLog < ActiveRecord::Base
  module Provider
    OpenAI = 1
  end
end
