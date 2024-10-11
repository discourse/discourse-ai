# frozen_string_literal: true

module DiscourseAi
  module Discord
    class BotController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      skip_before_action :verify_authenticity_token

      def interactions
        # Request signature verification
        begin
          verify_request!
        rescue Ed25519::VerifyError
          return head :unauthorized
        end

        body = JSON.parse(request.body.read)

        if body["type"] == 1
          # Respond to Discord PING request
          render json: { type: 1 }
        else
          response = { type: 5, data: { content: "Searching..." } }
          hijack { render json: response }

          pp request.headers
          pp body

          # Respond to /commands
          persona = DiscourseAi::AiBot::Personas::DiscourseHelper
          bot =
            DiscourseAi::AiBot::Bot.as(
              Discourse.system_user,
              persona: persona.new,
              model: "custom:6",
            )

          query = body["data"]["options"].first["value"]
          reply = ""
          reply =
            bot.reply({ conversation_context: [{ type: :user, content: query }] }) { |a, b, c| nil }

          pp reply.last.first

          discord_reply = reply.last.first

          api_endpoint =
            "https://discord.com/api/webhooks/#{SiteSetting.ai_discord_app_id}/#{body["token"]}"

          conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
          response =
            conn.post(
              api_endpoint,
              { content: discord_reply }.to_json,
              { "Content-Type" => "application/json" },
            )

          pp response
        end
      end

      private

      def verify_request!
        signature = request.headers["X-Signature-Ed25519"]
        timestamp = request.headers["X-Signature-Timestamp"]
        verify_key.verify([signature].pack("H*"), "#{timestamp}#{request.raw_post}")
      end

      def verify_key
        # TODO remove this gem dependency
        Ed25519::VerifyKey.new([SiteSetting.ai_discord_app_public_key].pack("H*")).freeze
      end
    end
  end
end
