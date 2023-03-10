# frozen_string_literal: true

module PageObjects
  module Modals
    class AIHelper < PageObjects::Modals::Base
      def visible?
        page.has_css?(".composer-ai-helper-modal")
      end

      def select_helper_mode(mode)
      end
    end
  end
end
