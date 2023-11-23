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

    let :image_function_list do
      function = Function.new(name: "image", description: "generates an image")

      function.add_parameter(
        name: "prompts",
        type: "array",
        item_type: "string",
        required: true,
        description: "the prompts",
      )

      list = FunctionList.new
      list << function
      list
    end

    it "can handle function call parsing" do
      raw_prompt = <<~PROMPT
      <function_calls>
      <invoke>
      <tool_name>image</tool_name>
      <parameters>
      <prompts>
      [
      "an oil painting",
      "a cute fluffy orange",
      "3 apple's",
      "a cat"
      ]
      </prompts>
      </parameters>
      </invoke>
      </function_calls>
      PROMPT
      parsed = image_function_list.parse_prompt(raw_prompt)
      expect(parsed).to eq(
        [
          {
            name: "image",
            arguments: {
              prompts: ["an oil painting", "a cute fluffy orange", "3 apple's", "a cat"],
            },
          },
        ],
      )
    end

    it "can generate a general custom system prompt" do
      prompt = function_list.system_prompt

      # this is fragile, by design, we need to test something here
      #
      expected = <<~PROMPT
        <tools>
        <tool_description>
        <tool_name>get_weather</tool_name>
        <description>Get the weather in a city (default to c)</description>
        <parameters>
        <parameter>
        <name>location</name>
        <type>string</type>
        <description>the city name</description>
        <required>true</required>
        </parameter>
        <parameter>
        <name>unit</name>
        <type>string</type>
        <description>the unit of measurement celcius c or fahrenheit f</description>
        <required>false</required>
        <options>c,f</options>
        </parameter>
        </parameters>
        </tool_description>
        </tools>
      PROMPT
      expect(prompt).to include(expected)
    end
  end
end
