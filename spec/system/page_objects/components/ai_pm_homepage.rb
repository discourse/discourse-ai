# frozen_string_literal: true

module PageObjects
  module Components
    class AiPmHomepage < PageObjects::Components::Base
      HOMEPAGE_BODY_CLASS = ".discourse-ai-bot-conversations-page"
      HOMEPAGE_WRAPPER_CLASS = ".custom-homepage__content-wrapper"

      def has_homepage?
        page.has_css?("#{HOMEPAGE_BODY_CLASS} #{HOMEPAGE_WRAPPER_CLASS}")
      end

      def has_no_homepage?
        page.has_no_css?("#{HOMEPAGE_BODY_CLASS} #{HOMEPAGE_WRAPPER_CLASS}")
      end
    end
  end
end
