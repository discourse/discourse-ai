# frozen_string_literal: true

module DiscourseAi
  module Personas
    class ToolRunner
      attr_reader :tool, :parameters, :llm
      attr_accessor :running_attached_function, :timeout, :custom_raw

      TooManyRequestsError = Class.new(StandardError)

      DEFAULT_TIMEOUT = 2000
      MAX_MEMORY = 10_000_000
      MARSHAL_STACK_DEPTH = 20
      MAX_HTTP_REQUESTS = 20

      MAX_SLEEP_CALLS = 30
      MAX_SLEEP_DURATION_MS = 60_000

      def initialize(parameters:, llm:, bot_user:, context: nil, tool:, timeout: nil)
        if context && !context.is_a?(DiscourseAi::Personas::BotContext)
          raise ArgumentError, "context must be a BotContext object"
        end

        context ||= DiscourseAi::Personas::BotContext.new

        @parameters = parameters
        @llm = llm
        @bot_user = bot_user
        @context = context
        @tool = tool
        @timeout = timeout || DEFAULT_TIMEOUT
        @running_attached_function = false

        @http_requests_made = 0
        @sleep_calls_made = 0
        @http_requests_made = 0
      end

      def mini_racer_context
        @mini_racer_context ||=
          begin
            ctx =
              MiniRacer::Context.new(
                max_memory: MAX_MEMORY,
                marshal_stack_depth: MARSHAL_STACK_DEPTH,
              )
            attach_truncate(ctx)
            attach_http(ctx)
            attach_index(ctx)
            attach_upload(ctx)
            attach_chain(ctx)
            attach_sleep(ctx)
            attach_discourse(ctx)
            ctx.eval(framework_script)
            ctx
          end
      end

      def framework_script
        http_methods = %i[get post put patch delete].map { |method| <<~JS }.join("\n")
          #{method}: function(url, options) {
            return _http_#{method}(url, options);
          },
          JS
        <<~JS
        const http = {
          #{http_methods}
        };

        const llm = {
          truncate: _llm_truncate,
          generate: _llm_generate,
        };

        const index = {
          search: _index_search,
        }

        const upload = {
          create: _upload_create,
          getUrl: _upload_get_url,
        }

        const chain = {
          setCustomRaw: _chain_set_custom_raw,
        };

        const discourse = {
          search: function(params) {
            return _discourse_search(params);
          },
          updatePersona: function(persona_id_or_name, updates) {
            const result = _discourse_update_persona(persona_id_or_name, updates);
            if (result.error) {
              throw new Error(result.error);
            }
            return result;
          },
          getPost: _discourse_get_post,
          getTopic: _discourse_get_topic,
          getUser: _discourse_get_user,
          getPersona: function(name) {
            const personaDetails = _discourse_get_persona(name);
            if (personaDetails.error) {
              throw new Error(personaDetails.error);
            }

            // merge result.persona with {}..
            return Object.assign({
              update: function(updates) {
                const result = _discourse_update_persona(name, updates);
                if (result.error) {
                  throw new Error(result.error);
                }
                return result;
              },
              respondTo: function(params) {
                const result = _discourse_respond_to_persona(name, params);
                if (result.error) {
                  throw new Error(result.error);
                }
                return result;
              }
            }, personaDetails.persona);
          },
          createChatMessage: function(params) {
            const result = _discourse_create_chat_message(params);
            if (result.error) {
              throw new Error(result.error);
            }
            return result;
          },
        };

        const context = #{JSON.generate(@context.to_json)};

        function details() { return ""; };
      JS
      end

      def details
        eval_with_timeout("details()")
      end

      def eval_with_timeout(script, timeout: nil)
        timeout ||= @timeout
        mutex = Mutex.new
        done = false
        elapsed = 0

        t =
          Thread.new do
            begin
              while !done
                # this is not accurate. but reasonable enough for a timeout
                sleep(0.001)
                elapsed += 1 if !self.running_attached_function
                if elapsed > timeout
                  mutex.synchronize { mini_racer_context.stop unless done }
                  break
                end
              end
            rescue => e
              STDERR.puts e
              STDERR.puts "FAILED TO TERMINATE DUE TO TIMEOUT"
            end
          end

        rval = mini_racer_context.eval(script)

        mutex.synchronize { done = true }

        # ensure we do not leak a thread in state
        t.join
        t = nil

        rval
      ensure
        # exceptions need to be handled
        t&.join
      end

      def invoke
        mini_racer_context.eval(tool.script)
        eval_with_timeout("invoke(#{JSON.generate(parameters)})")
      rescue MiniRacer::ScriptTerminatedError
        { error: "Script terminated due to timeout" }
      end

      def has_custom_context?
        mini_racer_context.eval(tool.script)
        mini_racer_context.eval("typeof customContext === 'function'")
      rescue StandardError
        false
      end

      def custom_context
        mini_racer_context.eval(tool.script)
        mini_racer_context.eval("customContext()")
      rescue StandardError
        nil
      end

      private

      MAX_FRAGMENTS = 200

      def rag_search(query, filenames: nil, limit: 10)
        limit = limit.to_i
        return [] if limit < 1
        limit = [MAX_FRAGMENTS, limit].min

        upload_refs =
          UploadReference.where(target_id: tool.id, target_type: "AiTool").pluck(:upload_id)

        if filenames
          upload_refs = Upload.where(id: upload_refs).where(original_filename: filenames).pluck(:id)
        end

        return [] if upload_refs.empty?

        query_vector = DiscourseAi::Embeddings::Vector.instance.vector_from(query)
        fragment_ids =
          DiscourseAi::Embeddings::Schema
            .for(RagDocumentFragment)
            .asymmetric_similarity_search(query_vector, limit: limit, offset: 0) do |builder|
              builder.join(<<~SQL, target_id: tool.id, target_type: "AiTool")
                rag_document_fragments ON
                  rag_document_fragments.id = rag_document_fragment_id AND
                  rag_document_fragments.target_id = :target_id AND
                  rag_document_fragments.target_type = :target_type
              SQL
            end
            .map(&:rag_document_fragment_id)

        fragments =
          RagDocumentFragment.where(id: fragment_ids, upload_id: upload_refs).pluck(
            :id,
            :fragment,
            :metadata,
          )

        mapped = {}
        fragments.each do |id, fragment, metadata|
          mapped[id] = { fragment: fragment, metadata: metadata }
        end

        fragment_ids.take(limit).map { |fragment_id| mapped[fragment_id] }
      end

      def attach_truncate(mini_racer_context)
        mini_racer_context.attach(
          "_llm_truncate",
          ->(text, length) { @llm.tokenizer.truncate(text, length) },
        )

        mini_racer_context.attach(
          "_llm_generate",
          ->(prompt) do
            in_attached_function do
              @llm.generate(
                convert_js_prompt_to_ruby(prompt),
                user: llm_user,
                feature_name: "custom_tool_#{tool.name}",
              )
            end
          end,
        )
      end

      def convert_js_prompt_to_ruby(prompt)
        if prompt.is_a?(String)
          prompt
        elsif prompt.is_a?(Hash)
          messages = prompt["messages"]
          if messages.blank? || !messages.is_a?(Array)
            raise Discourse::InvalidParameters.new("Prompt must have messages")
          end
          messages.each(&:symbolize_keys!)
          messages.each { |message| message[:type] = message[:type].to_sym }
          DiscourseAi::Completions::Prompt.new(messages: prompt["messages"])
        else
          raise Discourse::InvalidParameters.new("Prompt must be a string or a hash")
        end
      end

      def llm_user
        @llm_user ||=
          begin
            post&.user || @bot_user
          end
      end

      def post
        return @post if defined?(@post)
        post_id = @context.post_id
        @post = post_id && Post.find_by(id: post_id)
      end

      def attach_index(mini_racer_context)
        mini_racer_context.attach(
          "_index_search",
          ->(*params) do
            in_attached_function do
              query, options = params
              self.running_attached_function = true
              options ||= {}
              options = options.symbolize_keys
              self.rag_search(query, **options)
            end
          end,
        )
      end

      def attach_chain(mini_racer_context)
        mini_racer_context.attach("_chain_set_custom_raw", ->(raw) { self.custom_raw = raw })
      end

      # this is useful for polling apis
      def attach_sleep(mini_racer_context)
        mini_racer_context.attach(
          "sleep",
          ->(duration_ms) do
            @sleep_calls_made += 1
            if @sleep_calls_made > MAX_SLEEP_CALLS
              raise TooManyRequestsError.new("Tool made too many sleep calls")
            end

            duration_ms = duration_ms.to_i
            if duration_ms > MAX_SLEEP_DURATION_MS
              raise ArgumentError.new(
                      "Sleep duration cannot exceed #{MAX_SLEEP_DURATION_MS}ms (1 minute)",
                    )
            end

            raise ArgumentError.new("Sleep duration must be positive") if duration_ms <= 0

            in_attached_function do
              sleep(duration_ms / 1000.0)
              { slept: duration_ms }
            end
          end,
        )
      end

      def attach_discourse(mini_racer_context)
        mini_racer_context.attach(
          "_discourse_get_post",
          ->(post_id) do
            in_attached_function do
              post = Post.find_by(id: post_id)
              return nil if post.nil?
              guardian = Guardian.new(Discourse.system_user)
              obj =
                recursive_as_json(
                  PostSerializer.new(post, scope: guardian, root: false, add_raw: true),
                )
              topic_obj =
                recursive_as_json(
                  ListableTopicSerializer.new(post.topic, scope: guardian, root: false),
                )
              obj["topic"] = topic_obj
              obj
            end
          end,
        )

        mini_racer_context.attach(
          "_discourse_get_topic",
          ->(topic_id) do
            in_attached_function do
              topic = Topic.find_by(id: topic_id)
              return nil if topic.nil?
              guardian = Guardian.new(Discourse.system_user)
              recursive_as_json(ListableTopicSerializer.new(topic, scope: guardian, root: false))
            end
          end,
        )

        mini_racer_context.attach(
          "_discourse_get_user",
          ->(user_id_or_username) do
            in_attached_function do
              user = nil

              if user_id_or_username.is_a?(Integer) ||
                   user_id_or_username.to_i.to_s == user_id_or_username
                user = User.find_by(id: user_id_or_username.to_i)
              else
                user = User.find_by(username: user_id_or_username)
              end

              return nil if user.nil?

              guardian = Guardian.new(Discourse.system_user)
              recursive_as_json(UserSerializer.new(user, scope: guardian, root: false))
            end
          end,
        )

        mini_racer_context.attach(
          "_discourse_respond_to_persona",
          ->(persona_name, params) do
            in_attached_function do
              # if we have 1000s of personas this can be slow ... we may need to optimize
              persona_class = AiPersona.all_personas.find { |persona| persona.name == persona_name }
              return { error: "Persona not found" } if persona_class.nil?

              persona = persona_class.new
              bot = DiscourseAi::Personas::Bot.as(@bot_user || persona.user, persona: persona)
              playground = DiscourseAi::AiBot::Playground.new(bot)

              if @context.post_id
                post = Post.find_by(id: @context.post_id)
                return { error: "Post not found" } if post.nil?

                reply_post =
                  playground.reply_to(
                    post,
                    custom_instructions: params["instructions"],
                    whisper: params["whisper"],
                  )

                if reply_post
                  return(
                    { success: true, post_id: reply_post.id, post_number: reply_post.post_number }
                  )
                else
                  return { error: "Failed to create reply" }
                end
              elsif @context.message_id && @context.channel_id
                message = Chat::Message.find_by(id: @context.message_id)
                channel = Chat::Channel.find_by(id: @context.channel_id)
                return { error: "Message or channel not found" } if message.nil? || channel.nil?

                reply =
                  playground.reply_to_chat_message(message, channel, @context.context_post_ids)

                if reply
                  return { success: true, message_id: reply.id }
                else
                  return { error: "Failed to create chat reply" }
                end
              else
                return { error: "No valid context for response" }
              end
            end
          end,
        )

        mini_racer_context.attach(
          "_discourse_create_chat_message",
          ->(params) do
            in_attached_function do
              params = params.symbolize_keys
              channel_name = params[:channel_name]
              username = params[:username]
              message = params[:message]

              # Validate parameters
              return { error: "Missing required parameter: channel_name" } if channel_name.blank?
              return { error: "Missing required parameter: username" } if username.blank?
              return { error: "Missing required parameter: message" } if message.blank?

              # Find the user
              user = User.find_by(username: username)
              return { error: "User not found: #{username}" } if user.nil?

              # Find the channel
              channel = Chat::Channel.find_by(name: channel_name)
              if channel.nil?
                # Try finding by slug if not found by name
                channel = Chat::Channel.find_by(slug: channel_name.parameterize)
              end
              return { error: "Channel not found: #{channel_name}" } if channel.nil?

              begin
                guardian = Guardian.new(user)
                message =
                  ChatSDK::Message.create(
                    raw: message,
                    channel_id: channel.id,
                    guardian: guardian,
                    enforce_membership: !channel.direct_message_channel?,
                  )

                {
                  success: true,
                  message_id: message.id,
                  message: message.message,
                  created_at: message.created_at.iso8601,
                }
              rescue => e
                { error: "Failed to create chat message: #{e.message}" }
              end
            end
          end,
        )

        mini_racer_context.attach(
          "_discourse_search",
          ->(params) do
            in_attached_function do
              search_params = params.symbolize_keys
              if search_params.delete(:with_private)
                search_params[:current_user] = Discourse.system_user
              end
              search_params[:result_style] = :detailed
              results = DiscourseAi::Utils::Search.perform_search(**search_params)
              recursive_as_json(results)
            end
          end,
        )

        mini_racer_context.attach(
          "_discourse_get_persona",
          ->(persona_name) do
            in_attached_function do
              persona = AiPersona.find_by(name: persona_name)

              return { error: "Persona not found" } if persona.nil?

              # Return a subset of relevant persona attributes
              {
                persona:
                  persona.attributes.slice(
                    "id",
                    "name",
                    "description",
                    "enabled",
                    "system_prompt",
                    "temperature",
                    "top_p",
                    "vision_enabled",
                    "tools",
                    "max_context_posts",
                    "allow_chat_channel_mentions",
                    "allow_chat_direct_messages",
                    "allow_topic_mentions",
                    "allow_personal_messages",
                  ),
              }
            end
          end,
        )

        mini_racer_context.attach(
          "_discourse_update_persona",
          ->(persona_id_or_name, updates) do
            in_attached_function do
              # Find persona by ID or name
              persona = nil
              if persona_id_or_name.is_a?(Integer) ||
                   persona_id_or_name.to_i.to_s == persona_id_or_name
                persona = AiPersona.find_by(id: persona_id_or_name.to_i)
              else
                persona = AiPersona.find_by(name: persona_id_or_name)
              end

              return { error: "Persona not found" } if persona.nil?

              allowed_updates = {}

              if updates["system_prompt"].present?
                allowed_updates[:system_prompt] = updates["system_prompt"]
              end

              if updates["temperature"].is_a?(Numeric)
                allowed_updates[:temperature] = updates["temperature"]
              end

              allowed_updates[:top_p] = updates["top_p"] if updates["top_p"].is_a?(Numeric)

              if updates["description"].present?
                allowed_updates[:description] = updates["description"]
              end

              allowed_updates[:enabled] = updates["enabled"] if updates["enabled"].is_a?(
                TrueClass,
              ) || updates["enabled"].is_a?(FalseClass)

              if persona.update(allowed_updates)
                return(
                  {
                    success: true,
                    persona:
                      persona.attributes.slice(
                        "id",
                        "name",
                        "description",
                        "enabled",
                        "system_prompt",
                        "temperature",
                        "top_p",
                      ),
                  }
                )
              else
                return { error: persona.errors.full_messages.join(", ") }
              end
            end
          end,
        )
      end

      def attach_upload(mini_racer_context)
        mini_racer_context.attach(
          "_upload_get_url",
          ->(short_url) do
            in_attached_function do
              return nil if short_url.blank?

              sha1 = Upload.sha1_from_short_url(short_url)
              return nil if sha1.blank?

              upload = Upload.find_by(sha1: sha1)
              return nil if upload.nil?
              # TODO we may need to introduce an API to unsecure, secure uploads
              return nil if upload.secure?

              GlobalPath.full_cdn_url(upload.url)
            end
          end,
        )
        mini_racer_context.attach(
          "_upload_create",
          ->(filename, base_64_content) do
            begin
              in_attached_function do
                # protect against misuse
                filename = File.basename(filename)

                Tempfile.create(filename) do |file|
                  file.binmode
                  file.write(Base64.decode64(base_64_content))
                  file.rewind

                  upload =
                    UploadCreator.new(
                      file,
                      filename,
                      for_private_message: @context.private_message,
                    ).create_for(@bot_user.id)

                  { id: upload.id, short_url: upload.short_url, url: upload.url }
                end
              end
            end
          end,
        )
      end

      def attach_http(mini_racer_context)
        mini_racer_context.attach(
          "_http_get",
          ->(url, options) do
            begin
              @http_requests_made += 1
              if @http_requests_made > MAX_HTTP_REQUESTS
                raise TooManyRequestsError.new("Tool made too many HTTP requests")
              end

              in_attached_function do
                headers = (options && options["headers"]) || {}

                result = {}
                DiscourseAi::Personas::Tools::Tool.send_http_request(
                  url,
                  headers: headers,
                ) do |response|
                  result[:body] = response.body
                  result[:status] = response.code.to_i
                end

                result
              end
            end
          end,
        )

        %i[post put patch delete].each do |method|
          mini_racer_context.attach(
            "_http_#{method}",
            ->(url, options) do
              begin
                @http_requests_made += 1
                if @http_requests_made > MAX_HTTP_REQUESTS
                  raise TooManyRequestsError.new("Tool made too many HTTP requests")
                end

                in_attached_function do
                  headers = (options && options["headers"]) || {}
                  body = options && options["body"]

                  result = {}
                  DiscourseAi::Personas::Tools::Tool.send_http_request(
                    url,
                    method: method,
                    headers: headers,
                    body: body,
                  ) do |response|
                    result[:body] = response.body
                    result[:status] = response.code.to_i
                  end

                  result
                rescue => e
                  if Rails.env.development?
                    p url
                    p options
                    p e
                    puts e.backtrace
                  end
                  raise e
                end
              end
            end,
          )
        end
      end

      def in_attached_function
        self.running_attached_function = true
        yield
      ensure
        self.running_attached_function = false
      end

      def recursive_as_json(obj)
        case obj
        when Array
          obj.map { |item| recursive_as_json(item) }
        when Hash
          obj.transform_values { |value| recursive_as_json(value) }
        when ActiveModel::Serializer, ActiveModel::ArraySerializer
          recursive_as_json(obj.as_json)
        when ActiveRecord::Base
          recursive_as_json(obj.as_json)
        else
          # Handle objects that respond to as_json but aren't handled above
          if obj.respond_to?(:as_json)
            result = obj.as_json
            if result.equal?(obj)
              # If as_json returned the same object, return it to avoid infinite recursion
              result
            else
              recursive_as_json(result)
            end
          else
            # Primitive values like strings, numbers, booleans, nil
            obj
          end
        end
      end
    end
  end
end
