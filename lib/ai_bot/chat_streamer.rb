# frozen_string_literal: true
#
# Chat streaming APIs are a bit slow, this ensures we properly buffer results
# and stream as quickly as possible.

module DiscourseAi
  module AiBot
    class ChatStreamer
      attr_accessor :cancel
      attr_reader :reply,
                  :guardian,
                  :thread_id,
                  :force_thread,
                  :in_reply_to_id,
                  :channel,
                  :cancelled

      def initialize(message:, channel:, guardian:, thread_id:, in_reply_to_id:, force_thread:)
        @message = message
        @channel = channel
        @guardian = guardian
        @thread_id = thread_id
        @force_thread = force_thread
        @in_reply_to_id = in_reply_to_id

        @queue = Queue.new

        db = RailsMultisite::ConnectionManagement.current_db
        @worker_thread =
          Thread.new { RailsMultisite::ConnectionManagement.with_connection(db) { run } }

        @client_id =
          ChatSDK::Channel.start_reply(
            channel_id: message.chat_channel_id,
            guardian: guardian,
            thread_id: thread_id,
          )
      end

      def <<(partial)
        return if partial.to_s.empty?

        if @client_id
          ChatSDK::Channel.stop_reply(
            channel_id: @message.chat_channel_id,
            client_id: @client_id,
            guardian: @guardian,
            thread_id: @thread_id,
          )
          @client_id = nil
        end

        if @reply
          @queue << partial
        else
          create_reply(partial)
        end
      end

      def create_reply(message)
        @reply =
          ChatSDK::Message.create(
            raw: message,
            channel_id: channel.id,
            guardian: guardian,
            force_thread: force_thread,
            in_reply_to_id: in_reply_to_id,
            enforce_membership: !channel.direct_message_channel?,
          )

        ChatSDK::Message.start_stream(message_id: @reply.id, guardian: @guardian)

        if trailing = message.scan(/\s*\z/).first
          @queue << trailing
        end
      end

      def done
        @queue << :done
        @worker_thread.join
        ChatSDK::Message.stop_stream(message_id: @reply.id, guardian: @guardian)
        @reply
      end

      private

      def run
        done = false
        while !done
          buffer = +""
          popped = @queue.pop
          break if popped == :done

          buffer << popped

          begin
            while true
              popped = @queue.pop(true)
              if popped == :done
                done = true
                break
              end
              buffer << popped
            end
          rescue ThreadError
          end

          streaming = ChatSDK::Message.stream(message_id: reply.id, raw: buffer, guardian: guardian)
          if !streaming
            cancel.call
            @cancelled = true
          end
        end
      end
    end
  end
end
