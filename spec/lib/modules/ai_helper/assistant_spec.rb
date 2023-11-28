# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::Assistant do
  fab!(:user) { Fabricate(:user) }
  let(:prompt) { CompletionPrompt.find_by(id: mode) }

  let(:english_text) { <<~STRING }
    To perfect his horror, Caesar, surrounded at the base of the statue by the impatient daggers of his friends,
    discovers among the faces and blades that of Marcus Brutus, his protege, perhaps his son, and he no longer
    defends himself, but instead exclaims: 'You too, my son!' Shakespeare and Quevedo capture the pathetic cry.
  STRING

  describe "#generate_and_send_prompt" do
    context "when using a prompt that returns text" do
      let(:mode) { CompletionPrompt::TRANSLATE }

      let(:text_to_translate) { <<~STRING }
        Para que su horror sea perfecto, César, acosado al pie de la estatua por lo impacientes puñales de sus amigos,
        descubre entre las caras y los aceros la de Marco Bruto, su protegido, acaso su hijo,
        y ya no se defiende y exclama: ¡Tú también, hijo mío! Shakespeare y Quevedo recogen el patético grito.
      STRING

      it "Sends the prompt to the LLM and returns the response" do
        response =
          DiscourseAi::Completions::LLM.with_prepared_responses([english_text]) do
            subject.generate_and_send_prompt(prompt, text_to_translate, user)
          end

        expect(response[:suggestions]).to contain_exactly(english_text)
      end
    end

    context "when using a prompt that returns a list" do
      let(:mode) { CompletionPrompt::GENERATE_TITLES }

      let(:titles) do
        "<item>The solitary horse</item><item>The horse etched in gold</item><item>A horse's infinite journey</item><item>A horse lost in time</item><item>A horse's last ride</item>"
      end

      it "returns an array with each title" do
        expected = [
          "The solitary horse",
          "The horse etched in gold",
          "A horse's infinite journey",
          "A horse lost in time",
          "A horse's last ride",
        ]

        response =
          DiscourseAi::Completions::LLM.with_prepared_responses([titles]) do
            subject.generate_and_send_prompt(prompt, english_text, user)
          end

        expect(response[:suggestions]).to contain_exactly(*expected)
      end
    end
  end
end
