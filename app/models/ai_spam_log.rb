# frozen_string_literal: true
class AiSpamLog < ActiveRecord::Base
end

# == Schema Information
#
# Table name: ai_spam_logs
#
#  id                       :bigint           not null, primary key
#  post_id                  :bigint           not null
#  llm_model_id             :bigint           not null
#  last_ai_api_audit_log_id :bigint           not null
#  scan_count               :integer          default(1), not null
#  is_spam                  :boolean          not null
#  last_scan_payload        :text             default(""), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
