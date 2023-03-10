# frozen_string_literal: true

module PageObjects
  module Modals
    class AiHelper < PageObjects::Modals::Base
      def visible?
        page.has_css?(".composer-ai-helper-modal")
      end

      def select_helper_model(mode)
        find(".ai-helper-mode").click
        find(".select-kit-row[data-value=\"#{mode}\"]").click
      end

      def save_changes
        find(".modal-footer button.create").click
      end

      def select_title_suggestion(option_number)
        find("input#title-suggestion-#{option_number}").click
      end
    end
  end
end
