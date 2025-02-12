#frozen_string_literal: true

class DiscourseAi::Evals::Runner
  attr_reader :llms, :cases

  def self.evals_paths
    @eval_paths ||= Dir.glob(File.join(File.join(__dir__, "../cases"), "*/*.yml"))
  end

  def self.evals
    @evals ||= evals_paths.map { |path| DiscourseAi::Evals::Eval.new(path: path) }
  end

  def self.list
    evals.each(&:print)
  end

  def initialize(eval_name:, llms:)
    @llms = llms
    @eval = self.class.evals.find { |c| c.id == eval_name }

    if !@eval
      puts "Error: Unknown evaluation '#{eval_name}'"
      exit 1
    end

    if @llms.empty?
      puts "Error: Unknown model 'model'"
      exit 1
    end
  end

  def run!
    puts "Running evaluation '#{@eval.id}'"

    log_filename = "#{@eval.id}-#{Time.now.strftime("%Y%m%d-%H%M%S")}.log"
    logs_dir = File.join(__dir__, "../log")
    FileUtils.mkdir_p(logs_dir)
    log_file = File.join(logs_dir, log_filename)

    logger = Logger.new(File.open(log_file, "a"))
    logger.info("Starting evaluation '#{@eval.id}'")

    Thread.current[:llm_audit_log] = logger

    llms.each do |llm|
      if @eval.vision && !llm.vision?
        logger.info("Skipping LLM: #{llm.name} as it does not support vision")
        next
      end

      logger.info("Evaluating with LLM: #{llm.name}")
      print "#{llm.name}: "
      result = @eval.run(llm: llm)

      if result[:result] == :fail
        puts "Failed 🔴"
        puts "---- Expected ----\n#{result[:expected_output]}"
        puts "---- Actual ----\n#{result[:actual_output]}"
        logger.error("Evaluation failed with LLM: #{llm.name}")
      elsif result[:result] == :pass
        puts "Passed 🟢"
        logger.info("Evaluation passed with LLM: #{llm.name}")
      else
        STDERR.puts "Error: Unknown result #{eval.inspect}"
        logger.error("Unknown result: #{eval.inspect}")
      end
    end

    puts
    puts "Log file: #{log_file}"
  end
end
