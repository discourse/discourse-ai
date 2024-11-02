# frozen_string_literal: true

class DiscourseAi::Completions::AnthropicMessageProcessor
  class AnthropicToolCall
    attr_reader :name, :raw_json, :id

    def initialize(name, id)
      @name = name
      @id = id
      @raw_json = +""
    end

    def append(json)
      @raw_json << json
    end
  end

  attr_reader :tool_calls, :input_tokens, :output_tokens

  def initialize(streaming_mode:)
    @streaming_mode = streaming_mode
    @tool_calls = []
  end

  def to_xml_tool_calls(function_buffer)
    return function_buffer if @tool_calls.blank?

    function_buffer = Nokogiri::HTML5.fragment(<<~TEXT)
      <function_calls>
      </function_calls>
    TEXT

    @tool_calls.each do |tool_call|
      node =
        function_buffer.at("function_calls").add_child(
          Nokogiri::HTML5::DocumentFragment.parse(
            DiscourseAi::Completions::Endpoints::Base.noop_function_call_text + "\n",
          ),
        )

      params = JSON.parse(tool_call.raw_json, symbolize_names: true)
      xml = params.map { |name, value| "<#{name}>#{CGI.escapeHTML(value)}</#{name}>" }.join("\n")


      node.at("tool_name").content = tool_call.name
      node.at("tool_id").content = tool_call.id
      node.at("parameters").children = Nokogiri::HTML5::DocumentFragment.parse(xml) if xml.present?
    end

    function_buffer
  end

  def process_message(payload)
    result = ""
    parsed = JSON.parse(payload, symbolize_names: true)

    if @streaming_mode
      if parsed[:type] == "content_block_start" && parsed.dig(:content_block, :type) == "tool_use"
        tool_name = parsed.dig(:content_block, :name)
        tool_id = parsed.dig(:content_block, :id)
        @tool_calls << AnthropicToolCall.new(tool_name, tool_id) if tool_name
      elsif parsed[:type] == "content_block_start" || parsed[:type] == "content_block_delta"
        if @tool_calls.present?
          result = parsed.dig(:delta, :partial_json).to_s
          @tool_calls.last.append(result)
        else
          result = parsed.dig(:delta, :text).to_s
        end
      elsif parsed[:type] == "message_start"
        @input_tokens = parsed.dig(:message, :usage, :input_tokens)
      elsif parsed[:type] == "message_delta"
        @output_tokens =
          parsed.dig(:usage, :output_tokens) || parsed.dig(:delta, :usage, :output_tokens)
      elsif parsed[:type] == "message_stop"
        # bedrock has this ...
        if bedrock_stats = parsed.dig("amazon-bedrock-invocationMetrics".to_sym)
          @input_tokens = bedrock_stats[:inputTokenCount] || @input_tokens
          @output_tokens = bedrock_stats[:outputTokenCount] || @output_tokens
        end
      end
    else
      content = parsed.dig(:content)
      if content.is_a?(Array)
        tool_call = content.find { |c| c[:type] == "tool_use" }
        if tool_call
          @tool_calls << AnthropicToolCall.new(tool_call[:name], tool_call[:id])
          @tool_calls.last.append(tool_call[:input].to_json)
        else
          result = parsed.dig(:content, 0, :text).to_s
        end
      end

      @input_tokens = parsed.dig(:usage, :input_tokens)
      @output_tokens = parsed.dig(:usage, :output_tokens)
    end

    result
  end
end
