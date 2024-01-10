# frozen_string_literal: true

module DiscourseAi
  module Completions
    class Prompt
      INVALID_TURN = Class.new(StandardError)

      def initialize(system_msg, messages: [], tools: [])
        system_message = { type: :system, content: system_msg }

        messages.reduce(system_message) do |last_turn, new_turn|
          validate_turn(last_turn, new_turn)
          new_turn
        end

        @messages = messages.unshift(system_message)
        @tools = tools
      end

      attr_reader :system_message, :messages

      def push(type:, content:, id: nil)
        return if type == :system
        new_message = { type: type, content: content }

        new_message[:id] = type == :user ? clean_username(id) : id if id && type != :model

        validate_turn(messages.last, new_message)

        messages << new_message
      end

      attr_reader :messages
      attr_accessor :tools

      private

      def clean_username(username)
        if username.match?(/\0[a-zA-Z0-9_-]{1,64}\z/)
          username
        else
          # not the best in the world, but this is what we have to work with
          # if sites enable unicode usernames this can get messy
          username.gsub(/[^a-zA-Z0-9_-]/, "_")[0..63]
        end
      end

      def validate_turn(last_turn, new_turn)
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
