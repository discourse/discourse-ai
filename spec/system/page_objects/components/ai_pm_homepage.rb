# frozen_string_literal: true

module PageObjects
  module Components
    class AiPmHomepage < PageObjects::Components::Base
      HOMEPAGE_WRAPPER_CLASS = ".ai-bot-conversations__content-wrapper"

      def visit
        page.visit("/discourse-ai/ai-bot/conversations")
      end

      def input
        page.find("#ai-bot-conversations-input")
      end

      def submit
        page.find(".ai-conversation-submit").click
      end

      def has_too_short_dialog?
        page.find(
          ".dialog-content",
          text: I18n.t("js.discourse_ai.ai_bot.conversations.min_input_length_message"),
        )
      end

      def has_homepage?
        page.has_css?(HOMEPAGE_WRAPPER_CLASS)
      end

      def has_no_homepage?
        page.has_no_css?(HOMEPAGE_WRAPPER_CLASS)
      end

      def has_no_new_question_button?
        page.has_no_css?(".ai-new-question-button")
      end

      def click_new_question_button
        page.find(".ai-new-question-button").click
      end

      def click_fist_sidebar_conversation
        page.find(
          ".sidebar-section[data-section-name='ai-conversations-history'] a.sidebar-section-link:not(.date-heading)",
        ).click
      end

      def persona_selector
        PageObjects::Components::SelectKit.new(".persona-llm-selector__persona-dropdown")
      end

      def llm_selector
        PageObjects::Components::SelectKit.new(".persona-llm-selector__llm-dropdown")
      end
    end
  end
end
