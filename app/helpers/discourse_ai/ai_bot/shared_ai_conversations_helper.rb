# frozen_string_literal: true
module DiscourseAi
  module AiBot
    module SharedAiConversationsHelper
      # bump up version when assets change
      # long term we may want to change this cause it is hard to remember
      # to bump versions, but for now this does the job
      VERSION = "1"

      def share_asset_url(short_path)
        ::UrlHelper.local_cdn_url("/plugins/discourse-ai/ai-share/#{short_path}?#{VERSION}")
      end
    end
  end
end
