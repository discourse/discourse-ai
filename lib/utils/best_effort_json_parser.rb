# frozen_string_literal: true

module DiscourseAi
  module Utils
    class BestEffortJsonParser
      def self.extract_key(helper_response, schema_type, schema_key)
        schema_type = schema_type.to_sym
        schema_key = schema_key.to_sym

        return helper_response unless helper_response.is_a?(String)

        # First attempt: try to parse after removing markdown fences
        cleaned = helper_response.strip

        # Remove markdown code fences
        if cleaned.match?(/^```(?:json)?\s*\n/i)
          cleaned = cleaned.gsub(/^```(?:json)?\s*\n/i, "").gsub(/\n```\s*$/, "")
        end

        # Try standard JSON parse
        begin
          parsed = JSON.parse(cleaned)
          return extract_value(parsed, schema_key, schema_type)
        rescue JSON::ParserError
          # Continue to next attempt
        end

        # Second attempt: fix common JSON issues
        fixed_json =
          cleaned.gsub(/(\w+):/, '"\1":') # Fix unquoted keys
            .gsub(/'/, '\"') # Replace single quotes with double quotes

        begin
          parsed = JSON.parse(fixed_json)
          return extract_value(parsed, schema_key, schema_type)
        rescue JSON::ParserError
          # Continue to manual extraction
        end

        # Third attempt: manual extraction based on key
        if schema_key
          key_str = schema_key.to_s

          # Look for the key in various formats
          patterns = [
            /"#{key_str}"\s*:\s*"([^"]+)"/, # "key": "value"
            /'#{key_str}'\s*:\s*'([^']+)'/, # 'key': 'value'
            /#{key_str}\s*:\s*"([^"]+)"/, # key: "value"
            /#{key_str}\s*:\s*'([^']+)'/, # key: 'value'
            /"#{key_str}"\s*:\s*\[([^\]]+)\]/, # "key": [array]
            /'#{key_str}'\s*:\s*\[([^\]]+)\]/, # 'key': [array]
            /#{key_str}\s*:\s*\[([^\]]+)\]/, # key: [array]
          ]

          # For objects, handle separately to deal with nesting
          object_patterns = [
            /"#{key_str}"\s*:\s*\{/, # "key": {
            /'#{key_str}'\s*:\s*\{/, # 'key': {
            /#{key_str}\s*:\s*\{/, # key: {
          ]

          # Try string/array patterns first
          patterns.each do |pattern|
            if match = helper_response.match(pattern)
              value = match[1]

              case schema_type
              when :string
                return value
              when :array
                begin
                  return JSON.parse("[#{value}]")
                rescue StandardError
                  # Try to split by comma and clean up
                  items = value.split(",").map { |item| item.strip.gsub(/^['"]|['"]$/, "") }
                  return items
                end
              end
            end
          end

          # Try object patterns
          if schema_type == :object
            object_patterns.each do |pattern|
              if match = helper_response.match(pattern)
                # Find the starting brace position after the key
                start_pos = match.end(0) - 1 # Position of the opening brace
                if start_pos >= 0 && helper_response[start_pos] == "{"
                  # Extract the full object by counting braces
                  brace_count = 0
                  end_pos = start_pos

                  helper_response[start_pos..-1].each_char.with_index do |char, idx|
                    if char == "{"
                      brace_count += 1
                    elsif char == "}"
                      brace_count -= 1
                      if brace_count == 0
                        end_pos = start_pos + idx
                        break
                      end
                    end
                  end

                  if brace_count == 0
                    object_str = helper_response[start_pos..end_pos]
                    begin
                      return JSON.parse(object_str)
                    rescue StandardError
                      # Try to fix and parse
                      fixed = object_str.gsub(/(\w+):/, '"\1":').gsub(/'/, '"')
                      begin
                        return JSON.parse(fixed)
                      rescue StandardError
                        return {}
                      end
                    end
                  end
                end
              end
            end
          end
        end

        case schema_type
        when :array
          []
        when :object
          {}
        else
          ""
        end
      end

      def self.extract_value(parsed, schema_key, schema_type)
        return parsed unless parsed.is_a?(Hash) && schema_key

        value = parsed[schema_key.to_s]

        case schema_type
        when :array
          value.is_a?(Array) ? value : []
        when :object
          value.is_a?(Hash) ? value : {}
        else
          value.to_s
        end
      end
    end
  end
end
