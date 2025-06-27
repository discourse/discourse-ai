# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminAiFeatures < PageObjects::Pages::Base
      FEATURES_PAGE = ".ai-features"

      def visit
        page.visit("/admin/plugins/discourse-ai/ai-features")
        self
      end

      def toggle_configured
        page.find("#{FEATURES_PAGE} .ai-features__controls select").click
        page.find("option[value='configured']").click
      end

      def toggle_unconfigured
        page.find("#{FEATURES_PAGE} .ai-features__controls select").click
        page.find("option[value='unconfigured']").click
      end

      def has_listed_modules?(count)
        page.has_css?("#{FEATURES_PAGE} .ai-module", count: count)
      end

      def has_feature_persona?(feature_name, name)
        page.has_css?(
          "#{FEATURES_PAGE} .ai-feature-card[data-feature-name='#{feature_name}'] .ai-feature-card__persona-button .d-button-label",
          text: name,
        )
      end

      def has_feature_groups?(feature_name, groups)
        listed_groups =
          page.find(
            "#{FEATURES_PAGE} .ai-feature-card[data-feature-name='#{feature_name}'] .ai-feature-card__item-groups",
          )
        list_items = listed_groups.all("li", visible: true).map(&:text)

        list_items.sort == groups.sort
      end

      def click_edit_module(module_name)
        page.find("#{FEATURES_PAGE} .ai-module[data-module-name='#{module_name}'] .edit").click
      end
    end
  end
end
