# frozen_string_literal: true
require "rails_helper"

module DiscourseAi::Inference
  describe FunctionList do
    let :function_list do
      function =
        Function.new(name: "get_weather", description: "Get the weather in a city (default to c)")

      function.add_parameter(
        name: "location",
        type: "string",
        description: "the city name",
        required: true,
      )

      function.add_parameter(
        name: "unit",
        type: "string",
        description: "the unit of measurement celcius c or fahrenheit f",
        enum: %w[c f],
        required: false,
      )

      list = FunctionList.new
      list << function
      list
    end

    it "can handle complex parsing" do
      raw_prompt = <<~PROMPT
        !get_weather(location: "sydney", unit: "f")
        !get_weather  (location: sydney)
        !get_weather(location  : 'sydney's', unit: "m", invalid: "invalid")
        !get_weather(unit: "f", invalid: "invalid")
      PROMPT
      parsed = function_list.parse_prompt(raw_prompt)

      expect(parsed).to eq(
        [
          { name: "get_weather", arguments: { location: "sydney", unit: "f" } },
          { name: "get_weather", arguments: { location: "sydney" } },
          { name: "get_weather", arguments: { location: "sydney's" } },
        ],
      )
    end

    it "can generate a general custom system prompt" do
      prompt = function_list.system_prompt

      # this is fragile, by design, we need to test something here
      #
      expected = <<~PROMPT
        {
         // Get the weather in a city (default to c)
         get_weather(location: string [required] /* the city name */, unit: string [optional] /* the unit of measurement celcius c or fahrenheit f [valid values: c,f] */)
        }
      PROMPT
      expect(prompt).to include(expected)
    end
  end
end
