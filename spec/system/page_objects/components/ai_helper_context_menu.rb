# frozen_string_literal: true

module PageObjects
  module Components
    class AIHelperContextMenu < PageObjects::Components::Base
      COMPOSER_EDITOR_SELECTOR = ".d-editor-input"
      CONTEXT_MENU_SELECTOR = ".ai-helper-context-menu"
      TRIGGER_STATE_SELECTOR = "#{CONTEXT_MENU_SELECTOR}__trigger"
      OPTIONS_STATE_SELECTOR = "#{CONTEXT_MENU_SELECTOR}__options"
      LOADING_STATE_SELECTOR = "#{CONTEXT_MENU_SELECTOR}__loading"
      RESETS_STATE_SELECTOR = "#{CONTEXT_MENU_SELECTOR}__resets"
      REVIEW_STATE_SELECTOR = "#{CONTEXT_MENU_SELECTOR}__review"
      CUSTOM_PROMPT_SELECTOR = "#{CONTEXT_MENU_SELECTOR} .ai-custom-prompt"
      CUSTOM_PROMPT_INPUT_SELECTOR = "#{CUSTOM_PROMPT_SELECTOR}__input"
      CUSTOM_PROMPT_BUTTON_SELECTOR = "#{CUSTOM_PROMPT_SELECTOR}__submit"

      def click_ai_button
        find("#{TRIGGER_STATE_SELECTOR} .btn").click
      end

      def select_helper_model(mode)
        find("#{OPTIONS_STATE_SELECTOR} li[data-value=\"#{mode}\"] .btn").click
      end

      def click_undo_button
        find("#{RESETS_STATE_SELECTOR} .undo").click
      end

      def click_revert_button
        find("#{REVIEW_STATE_SELECTOR} .revert").click
      end

      def click_view_changes_button
        find("#{REVIEW_STATE_SELECTOR} .view-changes").click
      end

      def click_confirm_button
        find("#{REVIEW_STATE_SELECTOR} .confirm").click
      end

      def press_undo_keys
        find(COMPOSER_EDITOR_SELECTOR).send_keys([:control, "z"])
      end

      def press_escape_key
        find("body").send_keys(:escape)
      end

      def click_custom_prompt_button
        find(CUSTOM_PROMPT_BUTTON_SELECTOR).click
      end

      def fill_custom_prompt(content)
        find(CUSTOM_PROMPT_INPUT_SELECTOR).fill_in(with: content)
        self
      end

      def has_context_menu?
        page.has_css?(CONTEXT_MENU_SELECTOR)
      end

      def has_no_context_menu?
        page.has_no_css?(CONTEXT_MENU_SELECTOR)
      end

      def showing_triggers?
        page.has_css?(TRIGGER_STATE_SELECTOR)
      end

      def showing_options?
        page.has_css?(OPTIONS_STATE_SELECTOR)
      end

      def showing_loading?
        page.has_css?(LOADING_STATE_SELECTOR)
      end

      def showing_resets?
        page.has_css?(RESETS_STATE_SELECTOR)
      end

      def not_showing_resets?
        page.has_no_css?(RESETS_STATE_SELECTOR)
      end

      def has_custom_prompt?
        page.has_css?(CUSTOM_PROMPT_SELECTOR)
      end

      def has_no_custom_prompt?
        page.has_no_css?(CUSTOM_PROMPT_SELECTOR)
      end

      def has_custom_prompt_button?
        page.has_css?(CUSTOM_PROMPT_BUTTON_SELECTOR)
      end

      def has_no_custom_prompt_button?
        page.has_no_css?(CUSTOM_PROMPT_BUTTON_SELECTOR)
      end
    end
  end
end
