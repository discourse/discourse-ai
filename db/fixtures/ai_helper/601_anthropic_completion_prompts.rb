# frozen_string_literal: true
CompletionPrompt.seed do |cp|
  cp.id = -101
  cp.provider = "anthropic"
  cp.name = "translate"
  cp.prompt_type = CompletionPrompt.prompt_types[:text]
  cp.messages = [{ role: "Human", content: <<~TEXT }]
    I want you to act as an English translator, spelling corrector and improver. I will speak to you
    in any language and you will detect the language, translate it and answer in the corrected and 
    improved version of my text, in English. I want you to replace my simplified A0-level words and 
    sentences with more beautiful and elegant, upper level English words and sentences. 
    Keep the meaning same, but make them more literary. I will provide you with a text inside <input> tags,
    please put the translation between <ai></ai> tags.
  TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -102
  cp.provider = "anthropic"
  cp.name = "generate_titles"
  cp.prompt_type = CompletionPrompt.prompt_types[:list]
  cp.messages = [{ role: "Human", content: <<~TEXT }]
    I want you to act as a title generator for written pieces. I will provide you with a text inside <input> tags, 
    and you will generate five attention-grabbing titles. Please keep the title concise and under 20 words,
    and ensure that the meaning is maintained. Replies will utilize the language type of the topic.
    Please put each suggestion between <ai></ai> tags.
  TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -103
  cp.provider = "anthropic"
  cp.name = "proofread"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.messages = [{ role: "Human", content: <<~TEXT }]
      You are a markdown proofreader. You correct egregious typos and phrasing issues but keep the user's original voice.
      You do not touch code blocks. I will provide you with text to proofread. If nothing needs fixing, then you will echo the text back.

      Optionally, a user can specify intensity. Intensity 10 is a pedantic English teacher correcting the text.
      Intensity 1 is a minimal proofreader. By default, you operate at intensity 1.
      I will provide you with a text inside <input> tags,
      please reply with the corrected text between <ai></ai> tags.
    TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -104
  cp.provider = "anthropic"
  cp.name = "markdown_table"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.messages = [{ role: "Human", content: <<~TEXT }]
      You are a markdown table formatter, I will provide you text and you will format it into a markdown table.
      I will provide you with a text inside <input> tags,
      please reply with the corrected text between <ai></ai> tags.
    TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -105
  cp.provider = "anthropic"
  cp.name = "custom_prompt"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.messages = [{ role: "Human", content: <<~TEXT }]
      You are a helpful assistant, I will provide you with a text inside <input> tags,
      you will {{custom_prompt}} and you will reply with the result between <ai></ai> tags.
    TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -106
  cp.provider = "anthropic"
  cp.name = "explain"
  cp.prompt_type = CompletionPrompt.prompt_types[:text]
  cp.messages = [{ role: "Human", content: <<~TEXT }]
      You are a helpful assistant, I will provide you with a term inside <input> tags,
      and the context where it was used inside <context> tags, the title of the topic
      where it was used between <topic> tags, optionally the post it was written 
      in response to in <post> tags and you will reply with an explanation of what the
      term means in this context between <ai></ai> tags.
    TEXT
end
