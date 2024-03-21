#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Personas
      class Persona
        class << self
          def vision_enabled
            false
          end

          def vision_max_pixels
            1_048_576
          end

          def system_personas
            @system_personas ||= {
              Personas::General => -1,
              Personas::SqlHelper => -2,
              Personas::Artist => -3,
              Personas::SettingsExplorer => -4,
              Personas::Researcher => -5,
              Personas::Creative => -6,
              Personas::DallE3 => -7,
              Personas::DiscourseHelper => -8,
              Personas::GithubHelper => -9,
            }
          end

          def system_personas_by_id
            @system_personas_by_id ||= system_personas.invert
          end

          def all(user:)
            # listing tools has to be dynamic cause site settings may change
            AiPersona.all_personas.filter do |persona|
              next false if !user.in_any_groups?(persona.allowed_group_ids)

              if persona.system
                instance = persona.new
                (
                  instance.required_tools == [] ||
                    (instance.required_tools - all_available_tools).empty?
                )
              else
                true
              end
            end
          end

          def find_by(id: nil, name: nil, user:)
            all(user: user).find { |persona| persona.id == id || persona.name == name }
          end

          def name
            I18n.t("discourse_ai.ai_bot.personas.#{to_s.demodulize.underscore}.name")
          end

          def description
            I18n.t("discourse_ai.ai_bot.personas.#{to_s.demodulize.underscore}.description")
          end

          def all_available_tools
            tools = [
              Tools::ListCategories,
              Tools::Time,
              Tools::Search,
              Tools::Summarize,
              Tools::Read,
              Tools::DbSchema,
              Tools::SearchSettings,
              Tools::Summarize,
              Tools::SettingContext,
              Tools::RandomPicker,
              Tools::DiscourseMetaSearch,
              Tools::GithubFileContent,
              Tools::GithubPullRequestDiff,
            ]

            tools << Tools::GithubSearchCode if SiteSetting.ai_bot_github_access_token.present?

            tools << Tools::ListTags if SiteSetting.tagging_enabled
            tools << Tools::Image if SiteSetting.ai_stability_api_key.present?

            tools << Tools::DallE if SiteSetting.ai_openai_api_key.present?
            if SiteSetting.ai_google_custom_search_api_key.present? &&
                 SiteSetting.ai_google_custom_search_cx.present?
              tools << Tools::Google
            end

            tools
          end
        end

        def id
          self.class.system_personas[self.class]
        end

        def tools
          []
        end

        def required_tools
          []
        end

        def temperature
          nil
        end

        def top_p
          nil
        end

        def options
          {}
        end

        def available_tools
          self.class.all_available_tools.filter { |tool| tools.include?(tool) }
        end

        def craft_prompt(context)
          system_insts =
            system_prompt.gsub(/\{(\w+)\}/) do |match|
              found = context[match[1..-2].to_sym]
              found.nil? ? match : found.to_s
            end

          prompt =
            DiscourseAi::Completions::Prompt.new(
              <<~TEXT.strip,
            #{system_insts}
            #{available_tools.map(&:custom_system_message).compact_blank.join("\n")}
            #{rag_fragments_prompt(context[:conversation_context].to_a)}
          TEXT
              messages: context[:conversation_context].to_a,
              topic_id: context[:topic_id],
              post_id: context[:post_id],
            )

          prompt.max_pixels = self.class.vision_max_pixels if self.class.vision_enabled
          prompt.tools = available_tools.map(&:signature) if available_tools

          prompt
        end

        def find_tools(partial)
          return [] if !partial.include?("</invoke>")

          parsed_function = Nokogiri::HTML5.fragment(partial)
          parsed_function.css("invoke").map { |fragment| find_tool(fragment) }.compact
        end

        protected

        def find_tool(parsed_function)
          function_id = parsed_function.at("tool_id")&.text
          function_name = parsed_function.at("tool_name")&.text
          return nil if function_name.nil?

          tool_klass = available_tools.find { |c| c.signature.dig(:name) == function_name }
          return nil if tool_klass.nil?

          arguments = {}
          tool_klass.signature[:parameters].to_a.each do |param|
            name = param[:name]
            value = parsed_function.at(name)&.text

            if param[:type] == "array" && value
              value =
                begin
                  JSON.parse(value)
                rescue JSON::ParserError
                  nil
                end
            end

            arguments[name.to_sym] = value if value
          end

          tool_klass.new(
            arguments,
            tool_call_id: function_id || function_name,
            persona_options: options[tool_klass].to_h,
          )
        end

        def rag_fragments_prompt(conversation_context)
          upload_refs =
            UploadReference.where(target_id: id, target_type: "AiPersona").pluck(:upload_id)

          return nil if !SiteSetting.ai_embeddings_enabled?
          return nil if conversation_context.blank? || upload_refs.blank?

          latest_interactions =
            conversation_context
              .select { |ctx| %i[model user].include?(ctx[:type]) }
              .map { |ctx| ctx[:content] }
              .last(10)
              .join("\n")

          strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
          vector_rep =
            DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)

          interactions_vector = vector_rep.vector_from(latest_interactions)

          candidate_fragment_ids =
            vector_rep.asymmetric_rag_fragment_similarity_search(
              interactions_vector,
              persona_id: id,
              limit: 50,
              offset: 0,
            )

          guidance =
            RagDocumentFragment.where(upload_id: upload_refs, id: candidate_fragment_ids).pluck(
              :fragment,
            )

          if DiscourseAi::Inference::HuggingFaceTextEmbeddings.reranker_configured?
            ranks =
              DiscourseAi::Inference::HuggingFaceTextEmbeddings
                .rerank(conversation_context.last[:content], guidance)
                .to_a
                .take(10)
                .map { _1[:index] }

            if ranks.empty?
              guidance = guidance.take(10)
            else
              guidance = ranks.map { |idx| guidance[idx] }
            end
          else
            guidance = guidance.take(10)
          end

          <<~TEXT
          The following texts will give you additional guidance to elaborate a response.
          We included them because we believe they are relevant to this conversation topic.
          Take them into account to elaborate a response.

          Texts:

          #{guidance}

          TEXT
        end
      end
    end
  end
end
