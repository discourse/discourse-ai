# frozen_string_literal: true

module DiscourseAi
  module Completions
    class ToolCall
      attr_reader :id, :name, :parameters

      def initialize(id:, name:, parameters: nil)
        @id = id
        @name = name
        @parameters = parameters || {}
      end

      def ==(other)
        id == other.id && name == other.name && parameters == other.parameters
      end

      def to_s
        "#{name} - #{id} (\n#{parameters.map(&:to_s).join("\n")}\n)"
      end

    end
  end
end
