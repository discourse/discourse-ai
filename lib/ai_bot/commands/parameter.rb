# frozen_string_literal: true
module DiscourseAi
  module AiBot
    module Commands
      class Parameter
        attr_reader :item_type, :name, :description, :type, :enum, :required
        def initialize(name:, description:, type:, enum: nil, required: false, item_type: nil)
          @name = name
          @description = description
          @type = type
          @enum = enum
          @required = required
          @item_type = item_type
        end
      end
    end
  end
end
