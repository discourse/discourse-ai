# frozen_string_literal: true

module PageObjects
  module Components
    class AISuggestionDropdown < PageObjects::Components::Base
      TITLE_BUTTON_SELECTOR = ".suggestion-button.suggest-titles-button"
      CATEGORY_BUTTON_SELECTOR = ".suggestion-button.suggest-category-button"
      MENU_SELECTOR = ".ai-suggestions-menu"

      def click_suggest_titles_button
        find(TITLE_BUTTON_SELECTOR, visible: :all).click
      end

      def click_suggest_category_button
        find(CATEGORY_BUTTON_SELECTOR, visible: :all).click
      end

      def select_suggestion(index)
        find("#{MENU_SELECTOR} li[data-value=\"#{index}\"]").click
      end

      def suggestion_name(index)
        find("#{MENU_SELECTOR} li[data-value=\"#{index}\"]").text
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
