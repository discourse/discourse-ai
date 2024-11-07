# frozen_string_literal: true

module PageObjects
  module Components
    class AiSummaryBox < PageObjects::Components::Base
      SUMMARY_BUTTON_SELECTOR = ".ai-summarization-button button"
      SUMMARY_CONTAINER_SELECTOR = ".ai-summary-container"

      def click_summarize
        find(SUMMARY_BUTTON_SELECTOR).click
      end

      def click_regenerate_summary
        find("#{SUMMARY_CONTAINER_SELECTOR} .outdated-summary button").click
      end

      def has_summary?(summary)
        find("#{SUMMARY_CONTAINER_SELECTOR} .generated-summary p").text == summary
      end

      def has_generating_summary_indicator?
        find("#{SUMMARY_CONTAINER_SELECTOR} .ai-summary__generating-text").present?
      end
    end
  end
end
