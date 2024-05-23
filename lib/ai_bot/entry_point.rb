# frozen_string_literal: true

module DiscourseAi
  module AiBot
    USER_AGENT = "Discourse AI Bot 1.0 (https://www.discourse.org)"

    class EntryPoint
      REQUIRE_TITLE_UPDATE = "discourse-ai-title-update"
      BOT_MODEL_CUSTOM_FIELD = "bot_model_name"
      Bot = Struct.new(:id, :name, :llm)

      def self.all_bot_ids
        mentionable_persona_user_ids =
          AiPersona.mentionables.map { |mentionable| mentionable[:user_id] }
        mentionable_bot_users =
          User
            .joins(:_custom_fields)
            .where(active: true, user_custom_fields: { name: BOT_MODEL_CUSTOM_FIELD })
            .pluck(:user_id)

        mentionable_bot_users + mentionable_persona_user_ids
      end

      def self.find_participant_in(participant_ids)
        participant_data =
          UserCustomField
            .includes(:user)
            .where(users: { active: true }, name: BOT_MODEL_CUSTOM_FIELD, user_id: participant_ids)
            .last

        return if participant_data.nil?

        Bot.new(
          participant_data.user.id,
          participant_data.user.username_lower,
          participant_data.value,
        )
      end

      def self.find_user_from_model(model_name)
        UserCustomField
          .includes(:user)
          .find_by(name: BOT_MODEL_CUSTOM_FIELD, value: model_name)
          &.user
      end

      def self.enabled_user_ids_and_models_map
        enabled_models = SiteSetting.ai_bot_enabled_chat_bots.split("|")

        DB.query_hash(<<~SQL, model_names: enabled_models, cf_name: BOT_MODEL_CUSTOM_FIELD)
          SELECT users.username AS username, users.id AS id, ucf.value AS model_name
          FROM user_custom_fields ucf
          INNER JOIN users ON ucf.user_id = users.id
          WHERE ucf.name = :cf_name 
          AND ucf.value IN (:model_names)
        SQL
      end

      # Most errors are simply "not_allowed"
      # we do not want to reveal information about this system
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
        plugin.register_modifier(:chat_allowed_bot_user_ids) do |user_ids, guardian|
          if guardian.user
            allowed_chat = AiPersona.allowed_chat(user: guardian.user)
            allowed_bot_ids = allowed_chat.map { |info| info[:user_id] }
            user_ids.concat(allowed_bot_ids)
          end
          user_ids
        end

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
          :can_debug_ai_bot_conversations,
          include_condition: -> do
            SiteSetting.ai_bot_enabled && scope.authenticated? &&
              SiteSetting.ai_bot_debugging_allowed_groups.present? &&
              scope.user.in_any_groups?(SiteSetting.ai_bot_debugging_allowed_groups_map)
          end,
        ) { true }

        plugin.add_to_serializer(
          :current_user,
          :ai_enabled_chat_bots,
          include_condition: -> do
            SiteSetting.ai_bot_enabled && scope.authenticated? &&
              scope.user.in_any_groups?(SiteSetting.ai_bot_allowed_groups_map)
          end,
        ) do
          bots_map = ::DiscourseAi::AiBot::EntryPoint.enabled_user_ids_and_models_map

          persona_users = AiPersona.persona_users(user: scope.user)
          if persona_users.present?
            bots_map.concat(
              persona_users.map do |persona_user|
                {
                  "id" => persona_user[:user_id],
                  "username" => persona_user[:username],
                  "mentionable" => persona_user[:mentionable],
                }
              end,
            )
          end

          bots_map
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

        plugin.on(:chat_message_created) do |chat_message, channel, user, context|
          DiscourseAi::AiBot::Playground.schedule_chat_reply(chat_message, channel, user, context)
        end

        if plugin.respond_to?(:register_editable_topic_custom_field)
          plugin.register_editable_topic_custom_field(:ai_persona_id)
        end

        plugin.on(:site_setting_changed) do |name, old_value, new_value|
          if name == :ai_embeddings_model && SiteSetting.ai_embeddings_enabled? &&
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
