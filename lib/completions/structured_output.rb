# frozen_string_literal: true

module DiscourseAi
  module Completions
    class StructuredOutput
      def initialize(json_schema_properties)
        @property_names = json_schema_properties.keys.map(&:to_sym)
        @property_cursors =
          json_schema_properties.reduce({}) do |m, (k, prop)|
            m[k.to_sym] = 0 if prop[:type] == "string"
            m
          end

        @tracked = {}

        @raw_response = +""
        @raw_cursor = 0

        @partial_json_tracker = JsonStreamingTracker.new(self)
      end

      attr_reader :last_chunk_buffer

      def <<(raw)
        @raw_response << raw
        @partial_json_tracker << raw
      end

      def read_buffered_property(prop_name)
        # Safeguard: If the model is misbehaving and generating something that's not a JSON,
        # treat response as a normal string.
        # This is a best-effort to recover from an unexpected scenario.
        if @partial_json_tracker.broken?
          unread_chunk = @raw_response[@raw_cursor..]
          @raw_cursor = @raw_response.length
          return unread_chunk
        end

        # Maybe we haven't read that part of the JSON yet.
        return nil if @tracked[prop_name].blank?

        # This means this property is a string and we want to return unread chunks.
        if @property_cursors[prop_name].present?
          unread = @tracked[prop_name][@property_cursors[prop_name]..]
          @property_cursors[prop_name] = @tracked[prop_name].length
          unread
        else
          # Ints and bools, and arrays are always returned as is.
          @tracked[prop_name]
        end
      end

      def notify_progress(key, value)
        key_sym = key.to_sym
        return if !@property_names.include?(key_sym)

        @tracked[key_sym] = value
      end
    end
  end
end
