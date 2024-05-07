# frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Tools
      class Tool
        class << self
          def signature
            raise NotImplemented
          end

          def name
            raise NotImplemented
          end

          def accepted_options
            []
          end

          def option(name, type:)
            Option.new(tool: self, name: name, type: type)
          end

          def help
            I18n.t("discourse_ai.ai_bot.command_help.#{signature[:name]}")
          end

          def custom_system_message
            nil
          end
        end

        attr_accessor :custom_raw
        attr_reader :tool_call_id, :persona_options, :bot_user, :llm, :context, :parameters

        def initialize(
          parameters,
          tool_call_id: "",
          persona_options: {},
          bot_user:,
          llm:,
          context: {}
        )
          @parameters = parameters
          @tool_call_id = tool_call_id
          @persona_options = persona_options
          @bot_user = bot_user
          @llm = llm
          @context = context
        end

        def name
          self.class.name
        end

        def summary
          I18n.t("discourse_ai.ai_bot.command_summary.#{name}")
        end

        def details
          I18n.t("discourse_ai.ai_bot.command_description.#{name}", description_args)
        end

        def help
          I18n.t("discourse_ai.ai_bot.command_help.#{name}")
        end

        def options
          self
            .class
            .accepted_options
            .reduce(HashWithIndifferentAccess.new) do |memo, option|
              val = @persona_options[option.name]
              memo[option.name] = val if val
              memo
            end
        end

        def chain_next_response?
          true
        end

        def standalone?
          false
        end

        protected

        def send_http_request(url, headers: {}, authenticate_github: false, follow_redirects: false)
          raise "Expecting caller to use a block" if !block_given?

          uri = nil
          url = UrlHelper.normalized_encode(url)
          uri =
            begin
              URI.parse(url)
            rescue StandardError
              nil
            end

          return if !uri

          if follow_redirects
            fd =
              FinalDestination.new(
                url,
                validate_uri: true,
                max_redirects: 5,
                follow_canonical: true,
              )

            uri = fd.resolve
          end

          return if uri.blank?

          request = FinalDestination::HTTP::Get.new(uri)
          request["User-Agent"] = DiscourseAi::AiBot::USER_AGENT
          headers.each { |k, v| request[k] = v }
          if authenticate_github && SiteSetting.ai_bot_github_access_token.present?
            request["Authorization"] = "Bearer #{SiteSetting.ai_bot_github_access_token}"
          end

          FinalDestination::HTTP.start(uri.hostname, uri.port, use_ssl: uri.port != 80) do |http|
            http.request(request) { |response| yield response }
          end
        end

        def read_response_body(response, max_length: 4.megabyte)
          body = +""
          response.read_body do |chunk|
            body << chunk
            break if body.bytesize > max_length
          end

          body[0..max_length]
        end

        def truncate(text, llm:, percent_length: nil, max_length: nil)
          if !percent_length && !max_length
            raise ArgumentError, "You must provide either percent_length or max_length"
          end

          target = llm.max_prompt_tokens
          target = (target * percent_length).to_i if percent_length

          if max_length
            target = max_length if target > max_length
          end

          llm.tokenizer.truncate(text, target)
        end

        def accepted_options
          []
        end

        def option(name, type:)
          Option.new(tool: self, name: name, type: type)
        end

        def description_args
          {}
        end

        def format_results(rows, column_names = nil, args: nil)
          rows = rows&.map { |row| yield row } if block_given?

          if !column_names
            index = -1
            column_indexes = {}

            rows =
              rows&.map do |data|
                new_row = []
                data.each do |key, value|
                  found_index = column_indexes[key.to_s] ||= (index += 1)
                  new_row[found_index] = value
                end
                new_row
              end
            column_names = column_indexes.keys
          end

          # this is not the most efficient format
          # however this is needed cause GPT 3.5 / 4 was steered using JSON
          result = { column_names: column_names, rows: rows }
          result[:args] = args if args
          result
        end
      end
    end
  end
end
