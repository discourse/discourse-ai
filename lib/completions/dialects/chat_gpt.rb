# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class ChatGpt < Dialect
        class << self
          def can_translate?(model_provider)
            model_provider == "open_ai" || model_provider == "azure"
          end
        end

        VALID_ID_REGEX = /\A[a-zA-Z0-9_]+\z/

        def native_tool_support?
          llm_model.provider == "open_ai" || llm_model.provider == "azure"
        end

        def translate
          @embed_user_ids =
            prompt.messages.any? do |m|
              m[:id] && m[:type] == :user && !m[:id].to_s.match?(VALID_ID_REGEX)
            end

          super
        end

        def max_prompt_tokens
          # provide a buffer of 120 tokens - our function counting is not
          # 100% accurate and getting numbers to align exactly is very hard
          buffer = (opts[:max_tokens] || 2500) + 50

          if tools.present?
            # note this is about 100 tokens over, OpenAI have a more optimal representation
            @function_size ||= llm_model.tokenizer_class.size(tools.to_json.to_s)
            buffer += @function_size
          end

          llm_model.max_prompt_tokens - buffer
        end

        # no support for streaming or tools or system messages
        def is_gpt_o?
          llm_model.provider == "open_ai" && llm_model.name.include?("o1-")
        end

        private

        def tools_dialect
          @tools_dialect ||= DiscourseAi::Completions::Dialects::OpenAiTools.new(prompt.tools)
        end

        def system_msg(msg)
          if is_gpt_o?
            { role: "user", content: msg[:content] }
          else
            { role: "system", content: msg[:content] }
          end
        end

        def model_msg(msg)
          { role: "assistant", content: msg[:content] }
        end

        def tool_call_msg(msg)
          tools_dialect.from_raw_tool_call(msg)
        end

        def tool_msg(msg)
          tools_dialect.from_raw_tool(msg)
        end

        def user_msg(msg)
          user_message = { role: "user", content: msg[:content] }

          if msg[:id]
            if @embed_user_ids
              user_message[:content] = "#{msg[:id]}: #{msg[:content]}"
            else
              user_message[:name] = msg[:id]
            end
          end

          user_message[:content] = inline_images(user_message[:content], msg) if vision_support?
          user_message
        end

        def inline_images(content, message)
          encoded_uploads = prompt.encoded_uploads(message)
          return content if encoded_uploads.blank?

          content_w_imgs =
            encoded_uploads.reduce([]) do |memo, details|
              memo << {
                type: "image_url",
                image_url: {
                  url: "data:#{details[:mime_type]};base64,#{details[:base64]}",
                },
              }
            end

          content_w_imgs << { type: "text", text: message[:content] }
        end

        def per_message_overhead
          # open ai defines about 4 tokens per message of overhead
          4
        end

        def calculate_message_token(context)
          llm_model.tokenizer_class.size(context[:content].to_s + context[:name].to_s)
        end
      end
    end
  end
end
