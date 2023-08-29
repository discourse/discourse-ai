# frozen_string_literal: true

module PageObjects
  module Components
    class AITitleSuggester < PageObjects::Components::Base
      BUTTON_SELECTOR = ".suggest-titles-button"
      MENU_SELECTOR = ".ai-title-suggestions-menu"

      def click_suggest_titles_button
        find(BUTTON_SELECTOR).click
      end

      def select_title_suggestion(index)
        find("#{MENU_SELECTOR} li[data-value=\"#{index}\"]").click
      end

      def has_dropdown?
        has_css?(MENU_SELECTOR)
      end

      def has_no_dropdown?
        has_no_css?(MENU_SELECTOR)
      end
    end
  end
end
