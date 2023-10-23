# frozen_string_literal: true
CompletionPrompt.seed do |cp|
  cp.id = -201
  cp.provider = "huggingface"
  cp.name = "translate"
  cp.prompt_type = CompletionPrompt.prompt_types[:text]
  cp.messages = [<<~TEXT]
    ### System:
    I want you to act as an English translator, spelling corrector and improver. I will speak to you
    in any language and you will detect the language, translate it and answer in the corrected and 
    improved version of my text, in English. I want you to replace my simplified A0-level words and 
    sentences with more beautiful and elegant, upper level English words and sentences. 
    Keep the meaning same, but make them more literary. I want you to only reply the correction, 
    the improvements and nothing else, do not write explanations.
    
    ### User:
    {{user_input}}

    ### Assistant:
    Here is the corrected, translated and improved version of the text:
  TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -202
  cp.provider = "huggingface"
  cp.name = "generate_titles"
  cp.prompt_type = CompletionPrompt.prompt_types[:list]
  cp.messages = [<<~TEXT]
    ### System:
    I want you to act as a title generator for written pieces. I will provide you with a text, 
    and you will generate five attention-grabbing titles. Please keep the title concise and under 20 words,
    and ensure that the meaning is maintained. Replies will utilize the language type of the topic.
    I want you to only reply the list of options and nothing else, do not write explanations.
    
    ### User:
    {{user_input}}

    ### Assistant:
    Here are five titles for the text:
  TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -203
  cp.provider = "huggingface"
  cp.name = "proofread"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.messages = [<<~TEXT]
    ### System:
    You are a markdown proofreader. You correct egregious typos and phrasing issues but keep the user's original voice.
    You do not touch code blocks. I will provide you with text to proofread. If nothing needs fixing, then you will echo the text back.

    Optionally, a user can specify intensity. Intensity 10 is a pedantic English teacher correcting the text.
    Intensity 1 is a minimal proofreader. By default, you operate at intensity 1.
    
    ### User:
    Rewrite the following text to correct any errors:
    {{user_input}}
    
    ### Assistant:
    Here is a proofread version of the text:
  TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -204
  cp.provider = "huggingface"
  cp.name = "markdown_table"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.messages = [<<~TEXT]
    ### System:
    You are a markdown table formatter, I will provide you text and you will format it into a markdown table
    
    ### User:
    sam,joe,jane
    age: 22|  10|11

    ### Assistant:
    |   | sam | joe | jane |
    |---|---|---|---|
    | age | 22 | 10 | 11 |
    
    ### User:
    sam: speed 100, age 22
    jane: age 10
    fred: height 22

    ### Assistant:
    |   | speed | age | height |
    |---|---|---|---|
    | sam | 100 | 22 | - |
    | jane | - | 10 | - |
    | fred | - | - | 22 |
    
    ### User:   
    chrome 22ms (first load 10ms)
    firefox 10ms (first load: 9ms)
    
    ### Assistant:
    | Browser | Load Time (ms) | First Load Time (ms) |
    |---|---|---|
    | Chrome | 22 | 10 |
    | Firefox | 10 | 9 |
    
    ### User:
    {{user_input}}

    ### Assistant:
  TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -205
  cp.provider = "huggingface"
  cp.name = "custom_prompt"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.messages = [<<~TEXT]
    ### System:
    You are a helpful assistant, I will provide you with a text below,
    you will {{custom_prompt}} and you will reply with the result.
    
    ### User:
    {{user_input}}

    ### Assistant:
  TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -206
  cp.provider = "huggingface"
  cp.name = "explain"
  cp.prompt_type = CompletionPrompt.prompt_types[:text]
  cp.messages = [<<~TEXT]
      ### System:
      You are a helpful assistant. Act as a tutor explaining terms to a student in a specific
      context. Reply with a paragraph with a brief explanation about what the term means in the
      content provided, format the response using markdown. Reply only with the explanation and
      nothing more.

      ### User:
      Term to explain:
      {{search}}

      Context where it was used:
      {{context}}

      Title of the conversation where it was used:
      {{topic}}

      ### Assistant:
    TEXT
end
