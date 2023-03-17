# frozen_string_literal: true
CompletionPrompt.seed do |cp|
  cp.id = 1
  cp.name = "translate"
  cp.prompt_type = CompletionPrompt.prompt_types[:text]
  cp.value = <<~STRING
    I want you to act as an English translator, spelling corrector and improver. I will speak to you
    in any language and you will detect the language, translate it and answer in the corrected and 
    improved version of my text, in English. I want you to replace my simplified A0-level words and 
    sentences with more beautiful and elegant, upper level English words and sentences. 
    Keep the meaning same, but make them more literary. I want you to only reply the correction, 
    the improvements and nothing else, do not write explanations.
  STRING
end

CompletionPrompt.seed do |cp|
  cp.id = 2
  cp.name = "generate_titles"
  cp.prompt_type = CompletionPrompt.prompt_types[:list]
  cp.value = <<~STRING
    I want you to act as a title generator for written pieces. I will provide you with a text, 
    and you will generate five attention-grabbing titles. Please keep the title concise and under 20 words,
    and ensure that the meaning is maintained. Replies will utilize the language type of the topic.
    I want you to only reply the list of options and nothing else, do not write explanations.
  STRING
end

CompletionPrompt.seed do |cp|
  cp.id = 3
  cp.name = "proofread"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.value = <<~STRING
    I want you act as a proofreader. I will provide you with a text and I want you to review them for any spelling, 
    grammar, or punctuation errors. Once you have finished reviewing the text, provide me with any necessary 
    corrections or suggestions for improve the text.
  STRING
end
