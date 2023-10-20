# frozen_string_literal: true
CompletionPrompt.seed do |cp|
  cp.id = -1
  cp.provider = "openai"
  cp.name = "translate"
  cp.prompt_type = CompletionPrompt.prompt_types[:text]
  cp.messages = [{ role: "system", content: <<~TEXT }]
    I want you to act as an English translator, spelling corrector and improver. I will speak to you
    in any language and you will detect the language, translate it and answer in the corrected and 
    improved version of my text, in English. I want you to replace my simplified A0-level words and 
    sentences with more beautiful and elegant, upper level English words and sentences. 
    Keep the meaning same, but make them more literary. I want you to only reply the correction, 
    the improvements and nothing else, do not write explanations.
  TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -2
  cp.provider = "openai"
  cp.name = "generate_titles"
  cp.prompt_type = CompletionPrompt.prompt_types[:list]
  cp.messages = [{ role: "system", content: <<~TEXT }]
    I want you to act as a title generator for written pieces. I will provide you with a text, 
    and you will generate five attention-grabbing titles. Please keep the title concise and under 20 words,
    and ensure that the meaning is maintained. Replies will utilize the language type of the topic.
    I want you to only reply the list of options and nothing else, do not write explanations.
  TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -3
  cp.provider = "openai"
  cp.name = "proofread"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.messages = [
    { role: "system", content: <<~TEXT },
      You are a markdown proofreader. You correct egregious typos and phrasing issues but keep the user's original voice.
      You do not touch code blocks. I will provide you with text to proofread. If nothing needs fixing, then you will echo the text back.

      Optionally, a user can specify intensity. Intensity 10 is a pedantic English teacher correcting the text.
      Intensity 1 is a minimal proofreader. By default, you operate at intensity 1.
    TEXT
    { role: "user", content: "![amazing car|100x100, 22%](upload://hapy.png)" },
    { role: "assistant", content: "![Amazing car|100x100, 22%](upload://hapy.png)" },
    { role: "user", content: <<~TEXT },
      Intensity 1:
      The rain in spain stays mainly in the plane.
    TEXT
    { role: "assistant", content: "The rain in Spain, stays mainly in the Plane." },
    { role: "user", content: "The rain in Spain, stays mainly in the Plane." },
    { role: "assistant", content: "The rain in Spain, stays mainly in the Plane." },
    { role: "user", content: <<~TEXT },
      Intensity 1:
      Hello,

      Sometimes the logo isn't changing automatically when color scheme changes.

      ![Screen Recording 2023-03-17 at 18.04.22|video](upload://2rcVL0ZMxHPNtPWQbZjwufKpWVU.mov)
    TEXT
    { role: "assistant", content: <<~TEXT },
      Hello,
      Sometimes the logo does not change automatically when the color scheme changes.
      ![Screen Recording 2023-03-17 at 18.04.22|video](upload://2rcVL0ZMxHPNtPWQbZjwufKpWVU.mov)
    TEXT
    { role: "user", content: <<~TEXT },
      Intensity 1:
      Any ideas what is wrong with this peace of cod?
      > This quot contains a typo
      ```ruby
      # this has speling mistakes
      testin.atypo = 11
      baad = "bad"
      ```
    TEXT
    { role: "assistant", content: <<~TEXT },
      Any ideas what is wrong with this piece of code?
      > This quot contains a typo
      ```ruby
      # This has spelling mistakes
      testing.a_typo = 11
      bad = "bad"
      ```
    TEXT
  ]
end

CompletionPrompt.seed do |cp|
  cp.id = -4
  cp.provider = "openai"
  cp.name = "markdown_table"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.messages = [
    { role: "system", content: <<~TEXT },
      You are a markdown table formatter, I will provide you text and you will format it into a markdown table
    TEXT
    { role: "user", content: "sam,joe,jane\nage: 22|  10|11" },
    { role: "assistant", content: <<~TEXT },
      |   | sam | joe | jane |
      |---|---|---|---|
      | age | 22 | 10 | 11 |
    TEXT
    { role: "user", content: <<~TEXT },
      sam: speed 100, age 22
      jane: age 10
      fred: height 22
    TEXT
    { role: "assistant", content: <<~TEXT },
      |   | speed | age | height |
      |---|---|---|---|
      | sam | 100 | 22 | - |
      | jane | - | 10 | - |
      | fred | - | - | 22 |
    TEXT
    { role: "user", content: <<~TEXT },
      chrome 22ms (first load 10ms)
      firefox 10ms (first load: 9ms)
    TEXT
    { role: "assistant", content: <<~TEXT },
      | Browser | Load Time (ms) | First Load Time (ms) |
      |---|---|---|
      | Chrome | 22 | 10 |
      | Firefox | 10 | 9 |
    TEXT
  ]
end

CompletionPrompt.seed do |cp|
  cp.id = -5
  cp.provider = "openai"
  cp.name = "custom_prompt"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.messages = [{ role: "system", content: <<~TEXT }]
    You are a helpful assistant, I will provide you with a text below,
    you will {{custom_prompt}} and you will reply with the result.
  TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -6
  cp.provider = "openai"
  cp.name = "explain"
  cp.prompt_type = CompletionPrompt.prompt_types[:text]
  cp.messages = [{ role: "Human", content: <<~TEXT }, { role: "Assistant", content: "" }]
      You are a helpful assistant. Act as a tutor explaining terms to a student in a specific
      context. Reply with a paragraph with a brief explanation about what the term means in the
      content provided, format the response using markdown. Reply only with the explanation and
      nothing more.

      Term to explain:
      {{search}}

      Context where it was used:
      {{context}}

      Title of the conversation where it was used:
      {{topic}}
      TEXT
end
