#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class SearchSettingsCommand < Command
    class << self
      def name
        "search_settings"
      end

      def desc
        "Will search through site settings and return top 20 results"
      end

      def parameters
        [
          Parameter.new(
            name: "query",
            description:
              "comma delimited list of settings to search for (e.g. 'setting_1,setting_2')",
            type: "string",
            required: true,
          ),
        ]
      end
    end

    def result_name
      "results"
    end

    def description_args
      { count: @last_num_results || 0, query: @last_query || "" }
    end

    INCLUDE_DESCRIPTIONS_MAX_LENGTH = 10
    MAX_RESULTS = 200

    def process(query:)
      @last_query = query
      @last_num_results = 0

      terms = query.split(",").map(&:strip).map(&:downcase).reject(&:blank?)

      found =
        SiteSetting.all_settings.filter do |setting|
          name = setting[:setting].to_s.downcase
          description = setting[:description].to_s.downcase
          plugin = setting[:plugin].to_s.downcase

          search_string = "#{name} #{description} #{plugin}"

          terms.any? { |term| search_string.include?(term) }
        end

      if found.blank?
        {
          args: {
            query: query,
          },
          rows: [],
          instruction: "no settings matched #{query}, expand your search",
        }
      else
        include_descriptions = false

        if found.length > MAX_RESULTS
          found = found[0..MAX_RESULTS]
        elsif found.length < INCLUDE_DESCRIPTIONS_MAX_LENGTH
          include_descriptions = true
        end

        @last_num_results = found.length

        format_results(found, args: { query: query }) do |setting|
          result = { name: setting[:setting] }
          if include_descriptions
            result[:description] = setting[:description]
            result[:plugin] = setting[:plugin]
          end
          result
        end
      end
    end
  end
end
