# frozen_string_literal: true

module DiscourseAi
  module Completions
    class Prompt
      INVALID_TURN = Class.new(StandardError)

      attr_reader :messages
      attr_accessor :tools, :topic_id, :post_id, :max_pixels, :tool_choice

      def initialize(
        system_message_text = nil,
        messages: [],
        tools: [],
        topic_id: nil,
        post_id: nil,
        max_pixels: nil,
        tool_choice: nil
      )
        raise ArgumentError, "messages must be an array" if !messages.is_a?(Array)
        raise ArgumentError, "tools must be an array" if !tools.is_a?(Array)

        @max_pixels = max_pixels || 1_048_576

        @topic_id = topic_id
        @post_id = post_id

        @messages = []

        if system_message_text
          system_message = { type: :system, content: system_message_text }
          @messages << system_message
        end

        @messages.concat(messages)

        @messages.each { |message| validate_message(message) }
        @messages.each_cons(2) { |last_turn, new_turn| validate_turn(last_turn, new_turn) }

        @tools = tools
        @tool_choice = tool_choice
      end

      # this new api tries to create symmetry between responses and prompts
      # this means anything we get back from the model via endpoint can be easily appended
      def push_model_response(response)
        response = [response] if !response.is_a? Array

        thinking, thinking_signature, redacted_thinking_signature = nil

        response.each do |message|
          if message.is_a?(Thinking)
            # we can safely skip partials here
            next if message.partial?
            if message.redacted
              redacted_thinking_signature = message.signature
            else
              thinking = message.message
              thinking_signature = message.signature
            end
          elsif message.is_a?(ToolCall)
            next if message.partial?
            # this is a bit surprising about the API
            # needing to add arguments is not ideal
            push(
              type: :tool_call,
              content: { arguments: message.parameters }.to_json,
              id: message.id,
              name: message.name,
            )
          elsif message.is_a?(String)
            push(type: :model, content: message)
          else
            raise ArgumentError, "response must be an array of strings, ToolCalls, or Thinkings"
          end
        end

        # anthropic rules are that we attach thinking to last for the response
        # it is odd, I wonder if long term we just keep thinking as a separate object
        if thinking || redacted_thinking_signature
          messages.last[:thinking] = thinking
          messages.last[:thinking_signature] = thinking_signature
          messages.last[:redacted_thinking_signature] = redacted_thinking_signature
        end
      end

      def push(
        type:,
        content:,
        id: nil,
        name: nil,
        upload_ids: nil,
        thinking: nil,
        thinking_signature: nil,
        redacted_thinking_signature: nil
      )
        return if type == :system
        new_message = { type: type, content: content }
        new_message[:name] = name.to_s if name
        new_message[:id] = id.to_s if id
        new_message[:upload_ids] = upload_ids if upload_ids
        new_message[:thinking] = thinking if thinking
        new_message[:thinking_signature] = thinking_signature if thinking_signature
        new_message[
          :redacted_thinking_signature
        ] = redacted_thinking_signature if redacted_thinking_signature

        validate_message(new_message)
        validate_turn(messages.last, new_message)

        messages << new_message
      end

      def has_tools?
        tools.present?
      end

      # helper method to get base64 encoded uploads
      # at the correct dimentions
      def encoded_uploads(message)
        return [] if message[:upload_ids].blank?
        UploadEncoder.encode(upload_ids: message[:upload_ids], max_pixels: max_pixels)
      end

      def ==(other)
        return false unless other.is_a?(Prompt)
        messages == other.messages && tools == other.tools && topic_id == other.topic_id &&
          post_id == other.post_id && max_pixels == other.max_pixels &&
          tool_choice == other.tool_choice
      end

      def eql?(other)
        self == other
      end

      def hash
        [messages, tools, topic_id, post_id, max_pixels, tool_choice].hash
      end

      private

      def validate_message(message)
        valid_types = %i[system user model tool tool_call]
        if !valid_types.include?(message[:type])
          raise ArgumentError, "message type must be one of #{valid_types}"
        end

        valid_keys = %i[
          type
          content
          id
          name
          upload_ids
          thinking
          thinking_signature
          redacted_thinking_signature
        ]
        if (invalid_keys = message.keys - valid_keys).any?
          raise ArgumentError, "message contains invalid keys: #{invalid_keys}"
        end

        if message[:type] == :upload_ids && !message[:upload_ids].is_a?(Array)
          raise ArgumentError, "upload_ids must be an array of ids"
        end

        if message[:upload_ids].present? && message[:type] != :user
          raise ArgumentError, "upload_ids are only supported for users"
        end

        raise ArgumentError, "message content must be a string" if !message[:content].is_a?(String)
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
