#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Commands
      class Command
        class << self
          def name
            raise NotImplemented
          end

          def invoked?(cmd_name)
            cmd_name == name
          end

          def desc
            raise NotImplemented
          end

          def extra_context
            ""
          end
        end

        def initialize(bot_user, args)
          @bot_user = bot_user
          @args = args
        end

        def standalone?
          false
        end

        def low_cost?
          false
        end

        def result_name
          raise NotImplemented
        end

        def name
          raise NotImplemented
        end

        def process(post)
          raise NotImplemented
        end

        def invoke_and_attach_result_to(post)
          post.post_custom_prompt ||= post.build_post_custom_prompt(custom_prompt: [])
          prompt = post.post_custom_prompt.custom_prompt || []

          prompt << ["!#{self.class.name} #{args}", bot_user.username]
          prompt << [process(args), result_name]

          post.post_custom_prompt.update!(custom_prompt: prompt)
        end

        protected

        attr_reader :bot_user, :args
      end
    end
  end
end
