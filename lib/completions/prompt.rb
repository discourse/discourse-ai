# frozen_string_literal: true

module DiscourseAi
  module Completions
    class Prompt
      INVALID_TURN = Class.new(StandardError)

      attr_reader :messages
      attr_accessor :tools, :topic_id, :post_id

      def initialize(
        system_message_text = nil,
        messages: [],
        tools: [],
        skip_validations: false,
        topic_id: nil,
        post_id: nil
      )
        raise ArgumentError, "messages must be an array" if !messages.is_a?(Array)
        raise ArgumentError, "tools must be an array" if !tools.is_a?(Array)

        @topic_id = topic_id
        @post_id = post_id

        @messages = []
        @skip_validations = skip_validations

        if system_message_text
          system_message = { type: :system, content: system_message_text }
          @messages << system_message
        end

        @messages.concat(messages)

        @messages.each { |message| validate_message(message) }
        @messages.each_cons(2) { |last_turn, new_turn| validate_turn(last_turn, new_turn) }

        @tools = tools
      end

      def push(type:, content:, id: nil)
        return if type == :system
        new_message = { type: type, content: content }
        new_message[:id] = id.to_s if id

        validate_message(new_message)
        validate_turn(messages.last, new_message)

        messages << new_message
      end

      private

      def validate_message(message)
        return if @skip_validations
        valid_types = %i[system user model tool tool_call]
        if !valid_types.include?(message[:type])
          raise ArgumentError, "message type must be one of #{valid_types}"
        end

        valid_keys = %i[type content id]
        if (invalid_keys = message.keys - valid_keys).any?
          raise ArgumentError, "message contains invalid keys: #{invalid_keys}"
        end

        raise ArgumentError, "message content must be a string" if !message[:content].is_a?(String)
      end

      def validate_turn(last_turn, new_turn)
        return if @skip_validations
        valid_types = %i[tool tool_call model user]
        raise INVALID_TURN if !valid_types.include?(new_turn[:type])

        if last_turn[:type] == :system && %i[tool tool_call model].include?(new_turn[:type])
          raise INVALID_TURN
        end

        raise INVALID_TURN if new_turn[:type] == :tool && last_turn[:type] != :tool_call
        raise INVALID_TURN if new_turn[:type] == :model && last_turn[:type] == :model
      end
    end
  end
end
