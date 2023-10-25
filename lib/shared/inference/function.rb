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

      def add_parameter(parameter = nil, **kwargs)
        if parameter
          add_parameter_kwargs(
            name: parameter.name,
            type: parameter.type,
            description: parameter.description,
            required: parameter.required,
            enum: parameter.enum,
            item_type: parameter.item_type,
          )
        else
          add_parameter_kwargs(**kwargs)
        end
      end

      def add_parameter_kwargs(
        name:,
        type:,
        description:,
        enum: nil,
        required: false,
        item_type: nil
      )
        param = { name: name, type: type, description: description, enum: enum, required: required }
        param[:enum] = enum if enum
        param[:item_type] = item_type if item_type

        @parameters << param
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
          definition[:items] = { type: parameter[:item_type] } if parameter[:item_type]
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
