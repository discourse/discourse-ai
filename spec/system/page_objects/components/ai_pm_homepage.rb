# frozen_string_literal: true

module PageObjects
  module Components
    class AiPmHomepage < PageObjects::Components::Base
      HOMEPAGE_WRAPPER_CLASS = ".ai-bot-conversations__content-wrapper"

      def input
        page.find("#ai-bot-conversations-input")
      end

      def submit
        page.find(".ai-conversation-submit").click
      end

      def has_too_short_dialog?
        page.find(".dialog-content", text: "Message must be longer than 10 characters")
      end

      def has_homepage?
        page.has_css?(HOMEPAGE_WRAPPER_CLASS)
      end

      def has_no_homepage?
        page.has_no_css?(HOMEPAGE_WRAPPER_CLASS)
      end
    end
  end
end
