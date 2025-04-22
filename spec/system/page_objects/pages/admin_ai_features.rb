# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminAiFeatures < PageObjects::Pages::Base
      CONFIGURED_FEATURES_TABLE = ".ai-feature-list__configured-features .d-admin-table"
      UNCONFIGURED_FEATURES_TABLE = ".ai-feature-list__unconfigured-features .d-admin-table"

      def visit
        page.visit("/admin/plugins/discourse-ai/ai-features")
        self
      end

      def configured_features_table
        page.find(CONFIGURED_FEATURES_TABLE)
      end

      def unconfigured_features_table
        page.find(UNCONFIGURED_FEATURES_TABLE)
      end

      def has_configured_feature_items?(count)
        page.has_css?("#{CONFIGURED_FEATURES_TABLE} .ai-feature-list__row", count: count)
      end

      def has_unconfigured_feature_items?(count)
        page.has_css?("#{UNCONFIGURED_FEATURES_TABLE} .ai-feature-list__row", count: count)
      end

      def has_feature_persona?(name)
        page.has_css?(
          "#{CONFIGURED_FEATURES_TABLE} .ai-feature-list__persona .d-button-label ",
          text: name,
        )
      end

      def has_feature_groups?(groups)
        listed_groups = page.find("#{CONFIGURED_FEATURES_TABLE} .ai-feature-list__groups")
        list_items = listed_groups.all("li", visible: true).map(&:text)

        list_items.sort == groups.sort
      end

      def click_edit_feature(feature_name)
        page.find(
          "#{CONFIGURED_FEATURES_TABLE} .ai-feature-list__row[data-feature-name='#{feature_name}'] .edit",
        ).click
      end
    end
  end
end
