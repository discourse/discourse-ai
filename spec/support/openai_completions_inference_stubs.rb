# frozen_string_literal: true

class OpenAiCompletionsInferenceStubs
  TRANSLATE = "translate"
  PROOFREAD = "proofread"
  GENERATE_TITLES = "generate_titles"

  class << self
    def text_mode_to_id(mode)
      case mode
      when TRANSLATE
        -1
      when PROOFREAD
        -3
      when GENERATE_TITLES
        -2
      end
    end

    def spanish_text
      <<~STRING
        Para que su horror sea perfecto, César, acosado al pie de la estatua por lo impacientes puñales de sus amigos,
        descubre entre las caras y los aceros la de Marco Bruto, su protegido, acaso su hijo,
        y ya no se defiende y exclama: ¡Tú también, hijo mío! Shakespeare y Quevedo recogen el patético grito.

        Al destino le agradan las repeticiones, las variantes, las simetrías; diecinueve siglos después,
        en el sur de la provincia de Buenos Aires, un gaucho es agredido por otros gauchos y, al caer,
        reconoce a un ahijado suyo y le dice con mansa reconvención y lenta sorpresa (estas palabras hay que oírlas, no leerlas):
        ¡Pero, che! Lo matan y no sabe que muere para que se repita una escena.
      STRING
    end

    def translated_response
      <<~STRING
        "To perfect his horror, Caesar, surrounded at the base of the statue by the impatient daggers of his friends,
        discovers among the faces and blades that of Marcus Brutus, his protege, perhaps his son, and he no longer
        defends himself, but instead exclaims: 'You too, my son!' Shakespeare and Quevedo capture the pathetic cry.

        Destiny favors repetitions, variants, symmetries; nineteen centuries later, in the southern province of Buenos Aires,
        a gaucho is attacked by other gauchos and, as he falls, recognizes a godson of his and says with gentle rebuke and
        slow surprise (these words must be heard, not read): 'But, my friend!' He is killed and does not know that he
        dies so that a scene may be repeated."
      STRING
    end

    def generated_titles
      <<~STRING
        1. "The Life and Death of a Nameless Gaucho"
        2. "The Faith of Iron and Courage: A Gaucho's Legacy"
        3. "The Quiet Piece that Moves Literature: A Gaucho's Story"
        4. "The Unknown Hero: A Gaucho's Sacrifice for Country"
        5. "From Dust to Legacy: The Enduring Name of a Gaucho"
      STRING
    end

    def proofread_response
      <<~STRING
        "This excerpt explores the idea of repetition and symmetry in tragic events. The author highlights two instances
        where someone is betrayed by a close friend or protege, uttering a similar phrase of surprise and disappointment
        before their untimely death. The first example refers to Julius Caesar, who upon realizing that one of his own
        friends and proteges, Marcus Brutus, is among his assassins, exclaims \"You too, my son!\" The second example
        is of a gaucho in Buenos Aires, who recognizes his godson among his attackers and utters the words of rebuke
        and surprise, \"But, my friend!\" before he is killed. The author suggests that these tragedies occur so that
        a scene may be repeated, emphasizing the cyclical nature of history and the inevitability of certain events."
      STRING
    end

    def response(content)
      {
        id: "chatcmpl-6sZfAb30Rnv9Q7ufzFwvQsMpjZh8S",
        object: "chat.completion",
        created: 1_678_464_820,
        model: "gpt-3.5-turbo-0301",
        usage: {
          prompt_tokens: 337,
          completion_tokens: 162,
          total_tokens: 499,
        },
        choices: [
          { message: { role: "assistant", content: content }, finish_reason: "stop", index: 0 },
        ],
      }
    end

    def response_text_for(type)
      case type
      when TRANSLATE
        translated_response
      when PROOFREAD
        proofread_response
      when GENERATE_TITLES
        generated_titles
      end
    end

    def stub_prompt(type)
      text = type == TRANSLATE ? spanish_text : translated_response

      prompt_messages = CompletionPrompt.find_by(name: type).messages_with_user_input(text)

      stub_response(prompt_messages, response_text_for(type))
    end

    def stub_response(messages, response_text, model: nil, req_opts: {})
      WebMock
        .stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .with(body: { model: model || "gpt-3.5-turbo", messages: messages }.merge(req_opts).to_json)
        .to_return(status: 200, body: JSON.dump(response(response_text)))
    end

    def stream_line(finish_reason: nil, delta: {})
      +"data: " << {
        id: "chatcmpl-#{SecureRandom.hex}",
        object: "chat.completion.chunk",
        created: 1_681_283_881,
        model: "gpt-3.5-turbo-0301",
        choices: [{ delta: delta }],
        finish_reason: finish_reason,
        index: 0,
      }.to_json
    end

    def stub_streamed_response(messages, deltas, model: nil, req_opts: {})
      chunks = deltas.map { |d| stream_line(delta: d) }
      chunks << stream_line(finish_reason: "stop")
      chunks << "[DONE]"
      chunks = chunks.join("\n\n")

      WebMock
        .stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .with(body: { model: model || "gpt-3.5-turbo", messages: messages }.merge(req_opts).to_json)
        .to_return(status: 200, body: chunks)
    end
  end
end
