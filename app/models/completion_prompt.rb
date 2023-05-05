# frozen_string_literal: true

class CompletionPrompt < ActiveRecord::Base
  # TODO(roman): Remove sept 2023.
  self.ignored_columns = ["value"]

  MAX_PROMPT_LENGTH = 3000

  enum :prompt_type, { text: 0, list: 1, diff: 2 }

  validates :messages, length: { maximum: 20 }
  validate :each_message_length

  def self.bot_prompt_with_topic_context(post)
    messages = []
    conversation =
      post
        .topic
        .posts
        .includes(:user)
        .where("post_number <= ?", post.post_number)
        .order("post_number desc")
        .pluck(:raw, :username)

    total_prompt_length = 0
    messages =
      conversation.reduce([]) do |memo, (raw, username)|
        total_prompt_length += raw.length
        break(memo) if total_prompt_length > MAX_PROMPT_LENGTH
        role = username == Discourse.gpt_bot.username ? "system" : "user"

        memo.unshift({ role: role, content: raw })
      end

    messages.unshift({ role: "system", content: <<~TEXT })
      You are gpt-bot. You answer questions and generate text.
      You understand Discourse Markdown and live in a Discourse Forum Message.
      You are provided you with context of previous discussions.
    TEXT

    messages
  end

  def messages_with_user_input(user_input)
    if ::DiscourseAi::AiHelper::LlmPrompt.new.enabled_provider == "openai"
      self.messages << { role: "user", content: user_input }
    else
      self.messages << { "role" => "Input", "content" => "<input>#{user_input}</input>" }
    end
  end

  private

  def each_message_length
    messages.each_with_index do |msg, idx|
      next if msg["content"].length <= 1000

      errors.add(:messages, I18n.t("errors.prompt_message_length", idx: idx + 1))
    end
  end
end

# == Schema Information
#
# Table name: completion_prompts
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  translated_name :string
#  prompt_type     :integer          default("text"), not null
#  enabled         :boolean          default(TRUE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  messages        :jsonb
#  provider        :text
#
# Indexes
#
#  index_completion_prompts_on_name  (name)
#
