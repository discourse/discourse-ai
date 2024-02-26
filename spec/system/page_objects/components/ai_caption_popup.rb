# frozen_string_literal: true

module PageObjects
  module Components
    class AiCaptionPopup < PageObjects::Components::Base
      GENERATE_CAPTION_SELECTOR = ".button-wrapper .generate-caption"
      CAPTION_POPUP_SELECTOR = ".ai-caption-popup"
      CAPTION_TEXTAREA_SELECTOR = "#{CAPTION_POPUP_SELECTOR} textarea"

      def click_generate_caption
        page.find(GENERATE_CAPTION_SELECTOR, visible: false).click
      end

      def has_caption_popup_value?(value)
        page.find(CAPTION_TEXTAREA_SELECTOR).value == value
      end

      def save_caption
        find("#{CAPTION_POPUP_SELECTOR} .btn-primary").click
      end
    end
  end
end
