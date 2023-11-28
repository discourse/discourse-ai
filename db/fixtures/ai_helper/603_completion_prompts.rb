# frozen_string_literal: true

# frozen_string_literal: true
CompletionPrompt.seed do |cp|
  cp.id = -301
  cp.name = "translate"
  cp.prompt_type = CompletionPrompt.prompt_types[:text]
  cp.messages = { insts: <<~TEXT }
    I want you to act as an English translator, spelling corrector and improver. I will write to you
    in any language and you will detect the language, translate it and answer in the corrected and
    improved version of my text, in English. I want you to replace my simplified A0-level words and
    sentences with more beautiful and elegant, upper level English words and sentences.
    Keep the meaning same, but make them more literary. I want you to only reply the correction,
    the improvements and nothing else, do not write explanations.
    You will find the text between <input></input> XML tags.
  TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -303
  cp.name = "proofread"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.messages = {
    insts: <<~TEXT,
      You are a markdown proofreader. You correct egregious typos and phrasing issues but keep the user's original voice.
      You do not touch code blocks. I will provide you with text to proofread. If nothing needs fixing, then you will echo the text back.
      Optionally, a user can specify intensity. Intensity 10 is a pedantic English teacher correcting the text.
      Intensity 1 is a minimal proofreader. By default, you operate at intensity 1.
      You will find the text between <input></input> XML tags.
    TEXT
    examples: [
      [
        "<input>![amazing car|100x100, 22%](upload://hapy.png)</input>",
        "![Amazing car|100x100, 22%](upload://hapy.png)",
      ],
      [<<~TEXT, "The rain in Spain, stays mainly in the Plane."],
        <input>
          Intensity 1:
          The rain in spain stays mainly in the plane.
        </input>
       TEXT
      [
        "The rain in Spain, stays mainly in the Plane.",
        "The rain in Spain, stays mainly in the Plane.",
      ],
      [<<~TEXT, <<~TEXT],
        <input>
          Intensity 1:
          Hello,
    
          Sometimes the logo isn't changing automatically when color scheme changes.
    
          ![Screen Recording 2023-03-17 at 18.04.22|video](upload://2rcVL0ZMxHPNtPWQbZjwufKpWVU.mov)
        </input>
      TEXT
        Hello,
        Sometimes the logo does not change automatically when the color scheme changes.
        ![Screen Recording 2023-03-17 at 18.04.22|video](upload://2rcVL0ZMxHPNtPWQbZjwufKpWVU.mov)
      TEXT
      [<<~TEXT, <<~TEXT],
        <input>
          Intensity 1:
          Any ideas what is wrong with this peace of cod?
          > This quot contains a typo
          ```ruby
          # this has speling mistakes
          testin.atypo = 11
          baad = "bad"
          ```
        </input>
      TEXT
        Any ideas what is wrong with this piece of code?
        > This quot contains a typo
        ```ruby
        # This has spelling mistakes
        testing.a_typo = 11
        bad = "bad"
        ```
    TEXT
    ],
  }
end

CompletionPrompt.seed do |cp|
  cp.id = -304
  cp.name = "markdown_table"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.messages = {
    insts: <<~TEXT,
    You are a markdown table formatter, I will provide you text inside <input></input> XML tags and you will format it into a markdown table
    TEXT
    examples: [
      ["<input>sam,joe,jane\nage: 22|  10|11</input>", <<~TEXT],
      |   | sam | joe | jane |
      |---|---|---|---|
      | age | 22 | 10 | 11 |
      TEXT
      [<<~TEXT, <<~TEXT],
        <input>
        sam: speed 100, age 22
        jane: age 10
        fred: height 22
        </input>
      TEXT
      |   | speed | age | height |
      |---|---|---|---|
      | sam | 100 | 22 | - |
      | jane | - | 10 | - |
      | fred | - | - | 22 |
      TEXT
      [<<~TEXT, <<~TEXT],
        <input>
          chrome 22ms (first load 10ms)
          firefox 10ms (first load: 9ms)
        </input>
      TEXT
      | Browser | Load Time (ms) | First Load Time (ms) |
      |---|---|---|
      | Chrome | 22 | 10 |
      | Firefox | 10 | 9 |
      TEXT
    ],
  }
end

CompletionPrompt.seed do |cp|
  cp.id = -305
  cp.name = "custom_prompt"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.messages = { insts: <<~TEXT }
    You are a helpful assistant. I will give you instructions inside <input></input> XML tags.
    You will look at them and reply with a result.
  TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -306
  cp.name = "explain"
  cp.prompt_type = CompletionPrompt.prompt_types[:text]
  cp.messages = { insts: <<~TEXT }
    You are a tutor explaining a term to a student in a specific context.
    
    I will provide everything you need to know inside <input> tags, which consists of the term I want you
    to explain inside <term> tags, the context of where it was used inside <context> tags, the title of
    the topic where it was used inside <topic> tags, and optionally, the previous post in the conversation
    in <replyTo> tags. 
    
    Using all this information, write a paragraph with a brief explanation 
    of what the term means. Format the response using Markdown. Reply only with the explanation and
    nothing more.
  TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -307
  cp.name = "generate_titles"
  cp.prompt_type = CompletionPrompt.prompt_types[:list]
  cp.messages = {
    insts: <<~TEXT,
      I want you to act as a title generator for written pieces. I will provide you with a text,
      and you will generate five attention-grabbing titles. Please keep the title concise and under 20 words,
      and ensure that the meaning is maintained. Replies will utilize the language type of the topic.
      I want you to only reply the list of options and nothing else, do not write explanations.
      Each title you generate must be separated by *.
      You will find the text between <input></input> XML tags.
    TEXT
    examples: [
      [
        "<input>In the labyrinth of time, a solitary horse, etched in gold by the setting sun, embarked on an infinite journey.</input>",
        "<item>The solitary horse</item><item>The horse etched in gold</item><item>A horse's infinite journey</item><item>A horse lost in time</item><item>A horse's last ride</item>",
      ],
    ],
    post_insts: "Wrap each title between <item></item> XML tags.",
  }
end
