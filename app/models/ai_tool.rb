# frozen_string_literal: true

class AiTool < ActiveRecord::Base
  class Runner
    attr_reader :tool, :parameters, :llm
    attr_accessor :running_attached_function

    TIMEOUT = 2000
    MAX_MEMORY = 10_000_000
    MARSHAL_STACK_DEPTH = 20

    def initialize(parameters, llm:, bot_user:, context: {}, tool:, timeout: nil)
      @parameters = parameters
      @llm = llm
      @bot_user = bot_user
      @context = context
      @tool = tool
      @timeout = timeout || TIMEOUT
      @running_attached_function = false
    end

    # mainly for testing
    def timeout=(value)
      @timeout = value
    end

    def mini_racer_context
      @mini_racer_context ||=
        MiniRacer::Context.new(max_memory: MAX_MEMORY, marshal_stack_depth: MARSHAL_STACK_DEPTH)
    end

    def framework_script
      <<~JS
        const http = {
          get: _http_get,
        };

        const llm = {
          truncate: _llm_truncate,
        };
      JS
    end

    def eval_with_timeout(script, timeout: nil)
      timeout ||= @timeout
      mutex = Mutex.new
      done = false
      elapsed = 0

      t =
        Thread.new do
          begin
            while !done
              # this is not accurate. but reasonable enough for a timeout
              sleep(0.001)
              elapsed += 1 if !self.running_attached_function
              if elapsed > timeout
                mutex.synchronize { mini_racer_context.stop unless done }
                break
              end
            end
          rescue => e
            STDERR.puts e
            STDERR.puts "FAILED TO TERMINATE DUE TO TIMEOUT"
          end
        end

      rval = mini_racer_context.eval(script)

      mutex.synchronize { done = true }

      # ensure we do not leak a thread in state
      t.join
      t = nil

      rval
    ensure
      # exceptions need to be handled
      t&.join
    end

    def invoke
      mini_racer_context.attach(
        "_http_get",
        ->(url, options) do
          begin
            self.running_attached_function = true
            headers = (options && options["headers"]) || {}

            result = {}
            DiscourseAi::AiBot::Tools::Tool.send_http_request(url, headers: headers) do |response|
              result[:body] = response.body
              result[:status] = response.code
            end

            result
          ensure
            self.running_attached_function = false
          end
        end,
      )

      # no timeout bypass here since it eats CPU
      mini_racer_context.attach(
        "_llm_truncate",
        ->(text, length) { @llm.tokenizer.truncate(text, length) },
      )

      mini_racer_context.eval(framework_script)
      mini_racer_context.eval(tool.script)
      eval_with_timeout("invoke(#{JSON.generate(parameters)})")
    rescue MiniRacer::ScriptTerminatedError
      { error: "Script terminated due to timeout" }
    end
  end

  validates :name, presence: true, length: { maximum: 255 }
  validates :description, presence: true, length: { maximum: 1000 }
  validates :parameters, presence: true
  validates :script, presence: true, length: { maximum: 100_000 }
  validates :created_by_id, presence: true

  def signature
    { name: name, description: description, parameters: parameters.map(&:symbolize_keys) }
  end

  def runner(parameters, llm:, bot_user:, context: {})
    Runner.new(parameters, llm: llm, bot_user: bot_user, context: context, tool: self)
  end
end

# == Schema Information
#
# Table name: ai_tools
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  description   :text             not null
#  parameters    :jsonb            not null
#  script        :text             not null
#  created_by_id :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
