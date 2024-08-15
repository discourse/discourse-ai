# frozen_string_literal: true

module PageObjects
  module Modals
    class DiffModal < PageObjects::Modals::Base
      def visible?
        page.has_css?(".composer-ai-helper-modal", wait: 5)
      end

      def confirm_changes
        find(".d-modal__footer button.confirm", wait: 5).click
      end

      def revert_changes
        find(".d-modal__footer button.revert", wait: 5).click
      end

      def old_value
        find(".composer-ai-helper-modal__old-value").text
      end

      def new_value
        find(".composer-ai-helper-modal__new-value").text
      end
    end
  end
end
