# frozen_string_literal: true

module DiscourseAi
  module Completions
    class Prompt
      INVALID_TURN = Class.new(StandardError)

      attr_reader :messages
      attr_accessor :tools, :topic_id, :post_id, :max_pixels

      def initialize(
        system_message_text = nil,
        messages: [],
        tools: [],
        skip_validations: false,
        topic_id: nil,
        post_id: nil,
        max_pixels: nil
      )
        raise ArgumentError, "messages must be an array" if !messages.is_a?(Array)
        raise ArgumentError, "tools must be an array" if !tools.is_a?(Array)

        @max_pixels = max_pixels || 1_048_576

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

      def push(type:, content:, id: nil, name: nil, uploads: nil)
        return if type == :system
        new_message = { type: type, content: content }
        new_message[:name] = name.to_s if name
        new_message[:id] = id.to_s if id
        new_message[:uploads] = uploads if uploads

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
        return [] if message[:uploads].blank?

        uploads =
          message[:uploads].map do |upload_id|
            upload = Upload.find(upload_id)
            next if upload.blank?
            next if upload.width.to_i == 0 || upload.height.to_i == 0

            original_pixels = upload.width * upload.height

            image = upload

            if original_pixels > max_pixels
              ratio = max_pixels.to_f / original_pixels

              new_width = (ratio * upload.width).to_i
              new_height = (ratio * upload.height).to_i

              image = upload.get_optimized_image(new_width, new_height)
            end

            mime_type = MiniMime.lookup_by_filename(upload.original_filename).content_type

            path = Discourse.store.path_for(image)
            if path.blank?
              # download is protected with a DistributedMutex
              external_copy = Discourse.store.download_safe(image)
              path = external_copy&.path
            end

            encoded = Base64.strict_encode64(File.read(path))

            { base64: encoded, mime_type: mime_type }
          end

        uploads
      end

      private

      def validate_message(message)
        return if @skip_validations
        valid_types = %i[system user model tool tool_call]
        if !valid_types.include?(message[:type])
          raise ArgumentError, "message type must be one of #{valid_types}"
        end

        valid_keys = %i[type content id name uploads]
        if (invalid_keys = message.keys - valid_keys).any?
          raise ArgumentError, "message contains invalid keys: #{invalid_keys}"
        end

        if message[:type] == :uploads && !message[:uploads].is_a?(Array)
          raise ArgumentError, "uploads must be an array"
        end

        if message[:type] == :uploads && message[:type] != :user
          raise ArgumentError, "uploads are only supported for users"
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
