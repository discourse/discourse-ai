# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ResponseHttpStreamer
      CRLF = "\r\n"
      POOL_SIZE = 10

      class << self
        def thread_pool
          @thread_pool ||=
            Concurrent::CachedThreadPool.new(min_threads: 0, max_threads: POOL_SIZE, idletime: 30)
        end

        def schedule_block(&block)
          # think about a better way to handle cross thread connections
          if Rails.env.test?
            block.call
            return
          end

          db = RailsMultisite::ConnectionManagement.current_db
          thread_pool.post do
            begin
              RailsMultisite::ConnectionManagement.with_connection(db) { block.call }
            rescue StandardError => e
              Discourse.warn_exception(e, message: "Discourse AI: Unable to stream reply")
            end
          end
        end

        # keeping this in a static method so we don't capture ENV and other bits
        # this allows us to release memory earlier
        def queue_streamed_reply(io, persona, user, topic, post)
          schedule_block do
            begin
              io.write "HTTP/1.1 200 OK"
              io.write CRLF
              io.write "Content-Type: text/plain; charset=utf-8"
              io.write CRLF
              io.write "Transfer-Encoding: chunked"
              io.write CRLF
              io.write "Cache-Control: no-cache, no-store, must-revalidate"
              io.write CRLF
              io.write "Connection: close"
              io.write CRLF
              io.write "X-Accel-Buffering: no"
              io.write CRLF
              io.write "X-Content-Type-Options: nosniff"
              io.write CRLF
              io.write CRLF
              io.flush

              persona_class =
                DiscourseAi::AiBot::Personas::Persona.find_by(id: persona.id, user: user)
              bot = DiscourseAi::AiBot::Bot.as(persona.user, persona: persona_class.new)

              data =
                {
                  topic_id: topic.id,
                  bot_user_id: persona.user.id,
                  persona_id: persona.id,
                }.to_json + "\n\n"

              io.write data.bytesize.to_s(16)
              io.write CRLF
              io.write data
              io.write CRLF

              DiscourseAi::AiBot::Playground
                .new(bot)
                .reply_to(post) do |partial|
                  next if partial.length == 0

                  data = { partial: partial }.to_json + "\n\n"

                  data.force_encoding("UTF-8")

                  io.write data.bytesize.to_s(16)
                  io.write CRLF
                  io.write data
                  io.write CRLF
                  io.flush
                end

              io.write "0"
              io.write CRLF
              io.write CRLF

              io.flush
              io.done
            rescue StandardError => e
              # make it a tiny bit easier to debug in dev, this is tricky
              # multi-threaded code that exhibits various limitations in rails
              p e if Rails.env.development?
              Discourse.warn_exception(e, message: "Discourse AI: Unable to stream reply")
            ensure
              io.close
            end
          end
        end
      end
    end
  end
end
