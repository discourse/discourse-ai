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

      def <<(json)
        # llm could send broken json
        # in that case just deal with it later
        # don't stream
        return if @broken

        begin
          @parser << json
        rescue DiscourseAi::Completions::ParserError
          @broken = true
          return
        end

        if @parser.state == :start_string && @current_key
          # this is is worth notifying
          stream_consumer.notify_progress(@current_key, @parser.buf)
        end

        @current_key = nil if @parser.state == :end_value
      end
    end
  end
end
