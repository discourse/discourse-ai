# frozen_string_literal: true

module DiscourseAi
  module AiBot
    USER_AGENT = "Discourse AI Bot 1.0 (https://www.discourse.org)"

    class EntryPoint
      REQUIRE_TITLE_UPDATE = "discourse-ai-title-update"

      GPT4_ID = -110
      GPT3_5_TURBO_ID = -111
      CLAUDE_V2_ID = -112
      GPT4_TURBO_ID = -113
      MIXTRAL_ID = -114
      GEMINI_ID = -115
      FAKE_ID = -116 # only used for dev and test
      CLAUDE_3_OPUS_ID = -117
      CLAUDE_3_SONNET_ID = -118
      CLAUDE_3_HAIKU_ID = -119
      COHERE_COMMAND_R_PLUS = -120

      BOTS = [
        [GPT4_ID, "gpt4_bot", "gpt-4"],
        [GPT3_5_TURBO_ID, "gpt3.5_bot", "gpt-3.5-turbo"],
        [CLAUDE_V2_ID, "claude_bot", "claude-2"],
        [GPT4_TURBO_ID, "gpt4t_bot", "gpt-4-turbo"],
        [MIXTRAL_ID, "mixtral_bot", "mixtral-8x7B-Instruct-V0.1"],
        [GEMINI_ID, "gemini_bot", "gemini-pro"],
        [FAKE_ID, "fake_bot", "fake"],
        [CLAUDE_3_OPUS_ID, "claude_3_opus_bot", "claude-3-opus"],
        [CLAUDE_3_SONNET_ID, "claude_3_sonnet_bot", "claude-3-sonnet"],
        [CLAUDE_3_HAIKU_ID, "claude_3_haiku_bot", "claude-3-haiku"],
        [COHERE_COMMAND_R_PLUS, "cohere_command_bot", "cohere-command-r-plus"],
      ]

      BOT_USER_IDS = BOTS.map(&:first)

      Bot = Struct.new(:id, :name, :llm)

      def self.all_bot_ids
        BOT_USER_IDS.concat(AiPersona.mentionables.map { |mentionable| mentionable[:user_id] })
      end

      def self.find_bot_by_id(id)
        found = DiscourseAi::AiBot::EntryPoint::BOTS.find { |bot| bot[0] == id }
        return if !found
        Bot.new(found[0], found[1], found[2])
      end

      def self.map_bot_model_to_user_id(model_name)
        case model_name
        in "gpt-4-turbo"
          GPT4_TURBO_ID
        in "gpt-3.5-turbo"
          GPT3_5_TURBO_ID
        in "gpt-4"
          GPT4_ID
        in "claude-2"
          CLAUDE_V2_ID
        in "mixtral-8x7B-Instruct-V0.1"
          MIXTRAL_ID
        in "gemini-pro"
          GEMINI_ID
        in "fake"
          FAKE_ID
        in "claude-3-opus"
          CLAUDE_3_OPUS_ID
        in "claude-3-sonnet"
          CLAUDE_3_SONNET_ID
        in "claude-3-haiku"
          CLAUDE_3_HAIKU_ID
        in "cohere-command-r-plus"
          COHERE_COMMAND_R_PLUS
        else
          nil
        end
      end

      # Most errors are simply "not_allowed"
      # we do not want to reveal information about this sytem
      # the 2 exceptions are "other_people_in_pm" and "other_content_in_pm"
      # in both cases you have access to the PM so we are not revealing anything
      def self.ai_share_error(topic, guardian)
        return nil if guardian.can_share_ai_bot_conversation?(topic)

        return :not_allowed if !guardian.can_see?(topic)

        # other people in PM
        if topic.topic_allowed_users.where("user_id > 0 and user_id <> ?", guardian.user.id).exists?
          return :other_people_in_pm
        end

        # other content in PM
        if topic.posts.where("user_id > 0 and user_id <> ?", guardian.user.id).exists?
          return :other_content_in_pm
        end

        :not_allowed
      end

      def inject_into(plugin)
        plugin.on(:site_setting_changed) do |name, _old_value, _new_value|
          if name == :ai_bot_enabled_chat_bots || name == :ai_bot_enabled ||
               name == :discourse_ai_enabled
            DiscourseAi::AiBot::SiteSettingsExtension.enable_or_disable_ai_bots
          end
        end

        Oneboxer.register_local_handler(
          "discourse_ai/ai_bot/shared_ai_conversations",
        ) do |url, route|
          if route[:action] == "show" && share_key = route[:share_key]
            if conversation = SharedAiConversation.find_by(share_key: share_key)
              conversation.onebox
            end
          end
        end

        plugin.on(:reduce_excerpt) do |doc, options|
          doc.css("details").remove if options && options[:strip_details]
        end

        plugin.register_seedfu_fixtures(
          Rails.root.join("plugins", "discourse-ai", "db", "fixtures", "ai_bot"),
        )

        plugin.add_to_serializer(
          :current_user,
          :ai_enabled_personas,
          include_condition: -> do
            SiteSetting.ai_bot_enabled && scope.authenticated? &&
              scope.user.in_any_groups?(SiteSetting.ai_bot_allowed_groups_map)
          end,
        ) do
          DiscourseAi::AiBot::Personas::Persona
            .all(user: scope.user)
            .map do |persona|
              { id: persona.id, name: persona.name, description: persona.description }
            end
        end

        plugin.add_to_serializer(
          :current_user,
          :ai_enabled_chat_bots,
          include_condition: -> do
            SiteSetting.ai_bot_enabled && scope.authenticated? &&
              scope.user.in_any_groups?(SiteSetting.ai_bot_allowed_groups_map)
          end,
        ) do
          model_map = {}
          SiteSetting
            .ai_bot_enabled_chat_bots
            .split("|")
            .each do |bot_name|
              model_map[
                ::DiscourseAi::AiBot::EntryPoint.map_bot_model_to_user_id(bot_name)
              ] = bot_name
            end

          # not 100% ideal, cause it is one extra query, but we need it
          bots = DB.query_hash(<<~SQL, user_ids: model_map.keys)
            SELECT username, id FROM users WHERE id IN (:user_ids)
          SQL

          bots.each { |hash| hash["model_name"] = model_map[hash["id"]] }
          mentionables = AiPersona.mentionables(user: scope.user)
          if mentionables.present?
            bots.concat(
              mentionables.map do |mentionable|
                { "id" => mentionable[:user_id], "username" => mentionable[:username] }
              end,
            )
          end
          bots
        end

        plugin.add_to_serializer(:current_user, :can_use_assistant) do
          scope.user.in_any_groups?(SiteSetting.ai_helper_allowed_groups_map)
        end

        plugin.add_to_serializer(:current_user, :can_use_assistant_in_post) do
          scope.user.in_any_groups?(SiteSetting.post_ai_helper_allowed_groups_map)
        end

        plugin.add_to_serializer(:current_user, :can_use_custom_prompts) do
          scope.user.in_any_groups?(SiteSetting.ai_helper_custom_prompts_allowed_groups_map)
        end

        plugin.add_to_serializer(:current_user, :can_share_ai_bot_conversations) do
          scope.user.in_any_groups?(SiteSetting.ai_bot_public_sharing_allowed_groups_map)
        end

        plugin.register_svg_icon("robot")

        plugin.add_to_serializer(
          :topic_view,
          :ai_persona_name,
          include_condition: -> { SiteSetting.ai_bot_enabled && object.topic.private_message? },
        ) do
          id = topic.custom_fields["ai_persona_id"]
          name =
            DiscourseAi::AiBot::Personas::Persona.find_by(user: scope.user, id: id.to_i)&.name if id
          name || topic.custom_fields["ai_persona"]
        end

        plugin.on(:post_created) { |post| DiscourseAi::AiBot::Playground.schedule_reply(post) }

        if plugin.respond_to?(:register_editable_topic_custom_field)
          plugin.register_editable_topic_custom_field(:ai_persona_id)
        end

        plugin.on(:site_setting_changed) do |name, old_value, new_value|
          if name == "ai_embeddings_model" && SiteSetting.ai_embeddings_enabled? &&
               new_value != old_value
            RagDocumentFragment.delete_all
            UploadReference
              .where(target: AiPersona.all)
              .each do |ref|
                Jobs.enqueue(
                  :digest_rag_upload,
                  ai_persona_id: ref.target_id,
                  upload_id: ref.upload_id,
                )
              end
          end
        end
      end
    end
  end
end
