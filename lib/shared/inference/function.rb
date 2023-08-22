# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class Function
      attr_reader :name, :description, :parameters, :type

      def initialize(name:, description:, type: nil)
        @name = name
        @description = description
        @type = type || "object"
        @parameters = []
      end

      def add_parameter(name:, type:, description:, enum: nil, required: false)
        @parameters << {
          name: name,
          type: type,
          description: description,
          enum: enum,
          required: required,
        }
      end

      def to_json(*args)
        as_json.to_json(*args)
      end

      def as_json
        required_params = []

        properties = {}
        parameters.each do |parameter|
          definition = { type: parameter[:type], description: parameter[:description] }
          definition[:enum] = parameter[:enum] if parameter[:enum]

          required_params << parameter[:name] if parameter[:required]
          properties[parameter[:name]] = definition
        end

        params = { type: @type, properties: properties }

        params[:required] = required_params if required_params.present?

        { name: name, description: description, parameters: params }
      end
    end
  end
end
