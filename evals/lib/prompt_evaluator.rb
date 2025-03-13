class DiscourseAi::Evals::PromptEvaluator
  def initialize(llm)
    @llm = llm.llm_model.to_llm
  end

  def prompt_call(prompts:, messages: nil, temperature: nil, tools: nil, stream: false)
    tools = symbolize_tools(tools)
    total = prompts.size * messages.size
    count = 0
    puts ""

    prompts.flat_map do |prompt|
      messages.map do |content|
        count += 1
        print "\rProcessing #{count}/#{total}"

        c_prompt =
          DiscourseAi::Completions::Prompt.new(prompt, messages: [{ type: :user, content: }])
        c_prompt.tools = tools if tools
        result = { prompt:, message: content }
        result[:result] = generate_result(c_prompt, temperature, stream)
        result
      end
    end
  ensure
    print "\r\033[K"
  end

  private

  def generate_result(c_prompt, temperature, stream)
    if stream
      stream_result = []
      @llm.generate(c_prompt, user: Discourse.system_user, temperature: temperature) do |partial|
        stream_result << partial
      end
      stream_result
    else
      @llm.generate(c_prompt, user: Discourse.system_user, temperature: temperature)
    end
  end

  def symbolize_tools(tools)
    return nil if tools.nil?

    tools.map do |tool|
      { name: tool["name"], parameters: tool["parameters"]&.transform_keys(&:to_sym) }.compact
    end
  end
end
