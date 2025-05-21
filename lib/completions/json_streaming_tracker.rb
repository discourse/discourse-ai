# frozen_string_literal: true

module DiscourseAi
  module Completions
    class JsonStreamingTracker
      attr_reader :current_key, :current_value, :stream_consumer

      def initialize(stream_consumer)
        @stream_consumer = stream_consumer
        @current_key = nil
        @current_value = nil
        @parser = DiscourseAi::Completions::JsonStreamingParser.new

        @parser.key do |k|
          @current_key = k
          @current_value = nil
        end

        @parser.value do |v|
          if @current_key
            stream_consumer.notify_progress(@current_key, v)
            @current_key = nil
          end
        end
      end

      def broken?
        @broken
      end

      def <<(raw_json)
        # llm could send broken json
        # in that case just deal with it later
        # don't stream
        return if @broken

        begin
          @parser << raw_json
        rescue DiscourseAi::Completions::ParserError
          # Note: We're parsing JSON content that was itself embedded as a string inside another JSON object.
          # During the outer JSON.parse, any escaped control characters (like "\\n") are unescaped to real characters ("\n"),
          # which corrupts the inner JSON structure when passed to the parser here.
          # To handle this, we retry parsing with the string JSON-escaped again (`.dump[1..-2]`) if the first attempt fails.
          try_escape_and_parse(raw_json)
          return if @broken
        end

        if @parser.state == :start_string && @current_key
          # this is is worth notifying
          stream_consumer.notify_progress(@current_key, @parser.buf)
        end

        @current_key = nil if @parser.state == :end_value
      end

      private

      def try_escape_and_parse(raw_json)
        if raw_json.blank? || !raw_json.is_a?(String)
          @broken = true
          return
        end
        # Escape the string as JSON and remove surrounding quotes
        escaped_json = raw_json.dump[1..-2]
        @parser << escaped_json
      rescue DiscourseAi::Completions::ParserError
        @broken = true
      end
    end
  end
end
