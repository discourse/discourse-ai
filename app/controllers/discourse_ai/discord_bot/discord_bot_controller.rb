# frozen_string_literal: true

module DiscourseAi
  module DiscordBot
    class DiscordBotController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      skip_before_action :verify_authenticity_token


      MY_PUBLIC_KEY = "6056aea5db8de8f0c1aa2494e45db790fd4a68c607785a9933ed186025f1c8c6".freeze

      def search
        # Request signature verification
        begin
          verify_request!
        rescue Ed25519::VerifyError
          return head :unauthorized
        end

        body = JSON.parse(request.body.read)

        if body['type'] == 1
          # Respond to Discord PING request
          render json: { type: 1 }
        else
          # Respond to /commands
          response = { type: 4, data: { content: 'This is a response' } }
          render json: response
        end
      end

      private
      def verify_request!
        signature = request.headers['X-Signature-Ed25519']
        timestamp = request.headers['X-Signature-Timestamp']
        verify_key.verify([signature].pack('H*'), "#{timestamp}#{request.raw_post}")
      end

      def verify_key
        Ed25519::VerifyKey.new([MY_PUBLIC_KEY].pack('H*')).freeze
      end
    end
  end
end
