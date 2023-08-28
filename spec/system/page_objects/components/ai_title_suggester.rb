# frozen_string_literal: true

module PageObjects
  module Components
    class AITitleSuggester < PageObjects::Components::Base
      BUTTON_SELECTOR = ".suggest-titles-button"
      MENU_SELECTOR = ".ai-title-suggestions-menu"

      def click_suggest_titles_button
        find(BUTTON_SELECTOR).click
      end
    end
  end
end
