# frozen_string_literal: true

module PageObjects
  module Modals
    class Summarization < PageObjects::Modals::Base
      def visible?
        page.has_css?(".ai-summary-modal", wait: 5)
      end

      def select_timeframe(option)
        find(".summarization-since").click
        find(".select-kit-row[data-value=\"#{option}\"]").click
      end

      def summary_value
        find(".summary-area").value
      end

      def generate_summary
        find(".ai-summary-modal .create").click
      end
    end
  end
end
