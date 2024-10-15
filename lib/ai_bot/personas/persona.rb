#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Personas
      class Persona
        class << self
          def rag_conversation_chunks
            10
          end

          def vision_enabled
            false
          end

          def vision_max_pixels
            1_048_576
          end

          def question_consolidator_llm
            nil
          end

          def force_default_llm
            false
          end

          def allow_chat_channel_mentions
            false
          end

          def allow_chat_direct_messages
            false
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
              Tools::Read,
              Tools::DbSchema,
              Tools::SearchSettings,
              Tools::SettingContext,
              Tools::RandomPicker,
              Tools::DiscourseMetaSearch,
              Tools::GithubFileContent,
              Tools::GithubPullRequestDiff,
              Tools::GithubSearchFiles,
              Tools::WebBrowser,
              Tools::JavascriptEvaluator,
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
          @ai_persona&.id || self.class.system_personas[self.class]
        end

        def tools
          []
        end

        def force_tool_use
          []
        end

        def forced_tool_count
          -1
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
          self
            .class
            .all_available_tools
            .filter { |tool| tools.include?(tool) }
            .concat(tools.filter(&:custom?))
        end

        def craft_prompt(context, llm: nil)
          system_insts =
            system_prompt.gsub(/\{(\w+)\}/) do |match|
              found = context[match[1..-2].to_sym]
              found.nil? ? match : found.to_s
            end

          prompt_insts = <<~TEXT.strip
          #{system_insts}
          #{available_tools.map(&:custom_system_message).compact_blank.join("\n")}
          TEXT

          question_consolidator_llm = llm
          if self.class.question_consolidator_llm.present?
            question_consolidator_llm =
              DiscourseAi::Completions::Llm.proxy(self.class.question_consolidator_llm)
          end

          fragments_guidance =
            rag_fragments_prompt(
              context[:conversation_context].to_a,
              llm: question_consolidator_llm,
              user: context[:user],
            )&.strip

          prompt_insts << fragments_guidance if fragments_guidance.present?

          prompt =
            DiscourseAi::Completions::Prompt.new(
              prompt_insts,
              messages: context[:conversation_context].to_a,
              topic_id: context[:topic_id],
              post_id: context[:post_id],
            )

          prompt.max_pixels = self.class.vision_max_pixels if self.class.vision_enabled
          prompt.tools = available_tools.map(&:signature) if available_tools

          prompt
        end

        def find_tools(partial, bot_user:, llm:, context:)
          return [] if !partial.include?("</invoke>")

          parsed_function = Nokogiri::HTML5.fragment(partial)
          parsed_function
            .css("invoke")
            .map do |fragment|
              tool_instance(fragment, bot_user: bot_user, llm: llm, context: context)
            end
            .compact
        end

        protected

        def tool_instance(parsed_function, bot_user:, llm:, context:)
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
                  [value.to_s]
                end
            elsif param[:type] == "string" && value
              value = strip_quotes(value).to_s
            elsif param[:type] == "integer" && value
              value = strip_quotes(value).to_i
            end

            if param[:enum] && value && !param[:enum].include?(value)
              # invalid enum value
              value = nil
            end

            arguments[name.to_sym] = value if value
          end

          tool_klass.new(
            arguments,
            tool_call_id: function_id || function_name,
            persona_options: options[tool_klass].to_h,
            bot_user: bot_user,
            llm: llm,
            context: context,
          )
        end

        def strip_quotes(value)
          if value.is_a?(String)
            if value.start_with?('"') && value.end_with?('"')
              value = value[1..-2]
            elsif value.start_with?("'") && value.end_with?("'")
              value = value[1..-2]
            else
              value
            end
          else
            value
          end
        end

        def rag_fragments_prompt(conversation_context, llm:, user:)
          upload_refs =
            UploadReference.where(target_id: id, target_type: "AiPersona").pluck(:upload_id)

          return nil if !SiteSetting.ai_embeddings_enabled?
          return nil if conversation_context.blank? || upload_refs.blank?

          latest_interactions =
            conversation_context.select { |ctx| %i[model user].include?(ctx[:type]) }.last(10)

          return nil if latest_interactions.empty?

          # first response
          if latest_interactions.length == 1
            consolidated_question = latest_interactions[0][:content]
          else
            consolidated_question =
              DiscourseAi::AiBot::QuestionConsolidator.consolidate_question(
                llm,
                latest_interactions,
                user,
              )
          end

          return nil if !consolidated_question

          strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
          vector_rep =
            DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)
          reranker = DiscourseAi::Inference::HuggingFaceTextEmbeddings

          interactions_vector = vector_rep.vector_from(consolidated_question)

          rag_conversation_chunks = self.class.rag_conversation_chunks

          candidate_fragment_ids =
            vector_rep.asymmetric_rag_fragment_similarity_search(
              interactions_vector,
              target_type: "AiPersona",
              target_id: id,
              limit:
                (
                  if reranker.reranker_configured?
                    rag_conversation_chunks * 5
                  else
                    rag_conversation_chunks
                  end
                ),
              offset: 0,
            )

          fragments =
            RagDocumentFragment.where(upload_id: upload_refs, id: candidate_fragment_ids).pluck(
              :fragment,
              :metadata,
            )

          if reranker.reranker_configured?
            guidance = fragments.map { |fragment, _metadata| fragment }
            ranks =
              DiscourseAi::Inference::HuggingFaceTextEmbeddings
                .rerank(conversation_context.last[:content], guidance)
                .to_a
                .take(rag_conversation_chunks)
                .map { _1[:index] }

            if ranks.empty?
              fragments = fragments.take(rag_conversation_chunks)
            else
              fragments = ranks.map { |idx| fragments[idx] }
            end
          end

          <<~TEXT
          <guidance>
          The following texts will give you additional guidance for your response.
          We included them because we believe they are relevant to this conversation topic.

          Texts:

          #{
            fragments
              .map do |fragment, metadata|
                if metadata.present?
                  ["# #{metadata}", fragment].join("\n")
                else
                  fragment
                end
              end
              .join("\n")
          }
          </guidance>
          TEXT
        end
      end
    end
  end
end
