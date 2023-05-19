#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Commands
      class Command
        def result_name
          raise NotImplemented
        end

        def name
          raise NotImplemented
        end

        def process(post, command_args)
          raise NotImplemented
        end
      end
    end
  end
end
