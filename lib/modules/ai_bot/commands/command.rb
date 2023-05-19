#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Commands
      class Command
        attr_reader :bot, :post

        def initialize(bot, post)
          @bot = bot
          @post = post
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

        def process(command_args)
          raise NotImplemented
        end
      end
    end
  end
end
