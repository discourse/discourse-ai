# frozen_string_literal: true

class AiApiAuditLog < ActiveRecord::Base
  module Provider
    OpenAI = 1
    Anthropic = 2
    HuggingFaceTextGeneration = 3
  end
end

# == Schema Information
#
# Table name: ai_api_audit_logs
#
#  id                   :bigint           not null, primary key
#  provider_id          :integer          not null
#  user_id              :integer
#  request_tokens       :integer
#  response_tokens      :integer
#  raw_request_payload  :string
#  raw_response_payload :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
