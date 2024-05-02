# frozen_string_literal: true

class DiscourseAi::Completions::FunctionCallNormalizer
  attr_reader :done

  # blk is the block to call with filtered data
  def initialize(blk, cancel)
    @blk = blk
    @cancel = cancel
    @done = false

    @in_tool = false

    @buffer = +""
    @function_buffer = +""
  end

  def self.normalize(data)
    text = +""
    cancel = -> {}
    blk = ->(partial, _) { text << partial }

    normalizer = self.new(blk, cancel)
    normalizer << data

    [text, normalizer.function_calls]
  end

  def function_calls
    return nil if @function_buffer.blank?

    xml = Nokogiri::HTML5.fragment(@function_buffer)
    self.class.normalize_function_ids!(xml)
    last_invoke = xml.at("invoke:last")
    if last_invoke
      last_invoke.next_sibling.remove while last_invoke.next_sibling
      xml.at("invoke:last").add_next_sibling("\n") if !last_invoke.next_sibling
    end
    xml.at("function_calls").to_s.dup.force_encoding("UTF-8")
  end

  def <<(text)
    @buffer << text

    if !@in_tool
      # double check if we are clearly in a tool
      search_length = text.length + 20
      search_string = @buffer[-search_length..-1] || @buffer

      index = search_string.rindex("<function_calls>")
      @in_tool = !!index
      if @in_tool
        @function_buffer = @buffer[index..-1]
        text_index = text.rindex("<function_calls>")
        @blk.call(text[0..text_index - 1].strip, @cancel) if text_index && text_index > 0
      end
    else
      @function_buffer << text
    end

    if !@in_tool
      if maybe_has_tool?(@buffer)
        split_index = text.rindex("<").to_i - 1
        if split_index >= 0
          @function_buffer = text[split_index + 1..-1] || ""
          text = text[0..split_index] || ""
        else
          @function_buffer << text
          text = ""
        end
      else
        if @function_buffer.length > 0
          @blk.call(@function_buffer, @cancel)
          @function_buffer = +""
        end
      end

      @blk.call(text, @cancel) if text.length > 0
    else
      if text.include?("</function_calls>")
        @done = true
        @cancel.call
      end
    end
  end

  def self.normalize_function_ids!(function_buffer)
    function_buffer
      .css("invoke")
      .each_with_index do |invoke, index|
        if invoke.at("tool_id")
          invoke.at("tool_id").content = "tool_#{index}" if invoke.at("tool_id").content.blank?
        else
          invoke.add_child("<tool_id>tool_#{index}</tool_id>\n") if !invoke.at("tool_id")
        end
      end
  end

  private

  def maybe_has_tool?(text)
    # 16 is the length of function calls
    substring = text[-16..-1] || text
    split = substring.split("<")

    if split.length > 1
      match = "<" + split.last
      "<function_calls>".start_with?(match)
    else
      substring.ends_with?("<")
    end
  end
end
