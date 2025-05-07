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

        @partial_json_tracker = JsonStreamingTracker.new(self)
      end

      attr_reader :last_chunk_buffer

      def <<(raw)
        @partial_json_tracker << raw
      end

      def read_latest_buffered_chunk
        @property_names.reduce({}) do |memo, pn|
          if @tracked[pn].present?
            # This means this property is a string and we want to return unread chunks.
            if @property_cursors[pn].present?
              unread = @tracked[pn][@property_cursors[pn]..]

              memo[pn] = unread if unread.present?
              @property_cursors[pn] = @tracked[pn].length
            else
              # Ints and bools are always returned as is.
              memo[pn] = @tracked[pn]
            end
          end

          memo
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
