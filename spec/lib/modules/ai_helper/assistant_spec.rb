# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::Assistant do
  fab!(:user)
  fab!(:empty_locale_user) { Fabricate(:user, locale: "") }
  let(:prompt) { CompletionPrompt.find_by(id: mode) }

  before { assign_fake_provider_to(:ai_helper_model) }

  let(:english_text) { <<~STRING }
    To perfect his horror, Caesar, surrounded at the base of the statue by the impatient daggers of his friends,
    discovers among the faces and blades that of Marcus Brutus, his protege, perhaps his son, and he no longer
    defends himself, but instead exclaims: 'You too, my son!' Shakespeare and Quevedo capture the pathetic cry.
  STRING

  describe("#custom_locale_instructions") do
    it "Properly generates the per locale system instruction" do
      SiteSetting.default_locale = "ko"
      expect(subject.custom_locale_instructions(user, false)).to eq(
        "It is imperative that you write your answer in Korean (한국어), you are interacting with a Korean (한국어) speaking user. Leave tag names in English.",
      )

      SiteSetting.allow_user_locale = true
      user.update!(locale: "he")

      expect(subject.custom_locale_instructions(user, false)).to eq(
        "It is imperative that you write your answer in Hebrew (עברית), you are interacting with a Hebrew (עברית) speaking user. Leave tag names in English.",
      )
    end

    it "returns sytstem instructions using Site locale if force_default_locale is true" do
      SiteSetting.default_locale = "ko"
      SiteSetting.allow_user_locale = true
      user.update!(locale: "he")

      expect(subject.custom_locale_instructions(user, true)).to eq(
        "It is imperative that you write your answer in Korean (한국어), you are interacting with a Korean (한국어) speaking user. Leave tag names in English.",
      )
    end
  end

  describe("#available_prompts") do
    before do
      SiteSetting.ai_helper_illustrate_post_model = "disabled"
      DiscourseAi::AiHelper::Assistant.clear_prompt_cache!
    end

    it "returns all available prompts" do
      prompts = subject.available_prompts(user)

      expect(prompts.length).to eq(8)
      expect(prompts.map { |p| p[:name] }).to contain_exactly(
        "translate",
        "generate_titles",
        "proofread",
        "markdown_table",
        "custom_prompt",
        "explain",
        "detect_text_locale",
        "replace_dates",
      )
    end

    it "returns all prompts to be shown in the composer" do
      prompts = subject.available_prompts(user)
      filtered_prompts = prompts.select { |prompt| prompt[:location].include?("composer") }
      expect(filtered_prompts.length).to eq(6)
      expect(filtered_prompts.map { |p| p[:name] }).to contain_exactly(
        "translate",
        "generate_titles",
        "proofread",
        "markdown_table",
        "custom_prompt",
        "replace_dates",
      )
    end

    it "returns all prompts to be shown in the post menu" do
      prompts = subject.available_prompts(user)
      filtered_prompts = prompts.select { |prompt| prompt[:location].include?("post") }
      expect(filtered_prompts.length).to eq(4)
      expect(filtered_prompts.map { |p| p[:name] }).to contain_exactly(
        "translate",
        "explain",
        "proofread",
        "custom_prompt",
      )
    end

    it "does not raise an error when effective_locale does not exactly match keys in LocaleSiteSetting" do
      SiteSetting.default_locale = "zh_CN"
      expect { subject.available_prompts(user) }.not_to raise_error
    end

    context "when illustrate post model is enabled" do
      before do
        SiteSetting.ai_helper_illustrate_post_model = "stable_diffusion_xl"
        DiscourseAi::AiHelper::Assistant.clear_prompt_cache!
      end

      it "returns the illustrate_post prompt in the list of all prompts" do
        prompts = subject.available_prompts(user)

        expect(prompts.length).to eq(9)
        expect(prompts.map { |p| p[:name] }).to contain_exactly(
          "translate",
          "generate_titles",
          "proofread",
          "markdown_table",
          "custom_prompt",
          "explain",
          "illustrate_post",
          "detect_text_locale",
          "replace_dates",
        )
      end
    end
  end

  describe("#localize_prompt!") do
    before { SiteSetting.allow_user_locale = true }

    it "is able to perform %LANGUAGE% replacements" do
      prompt =
        CompletionPrompt.new(messages: { insts: "This is a %LANGUAGE% test" }).messages_with_input(
          "test",
        )

      subject.localize_prompt!(prompt, user)

      expect(prompt.messages[0][:content].strip).to eq("This is a English (US) test")
    end

    it "handles users with empty string locales" do
      prompt =
        CompletionPrompt.new(messages: { insts: "This is a %LANGUAGE% test" }).messages_with_input(
          "test",
        )

      subject.localize_prompt!(prompt, empty_locale_user)

      expect(prompt.messages[0][:content].strip).to eq("This is a English (US) test")
    end

    context "with temporal context" do
      let(:prompt) do
        CompletionPrompt.new(
          messages: {
            insts: "Current context: {{temporal_context}}",
          },
        ).messages_with_input("test")
      end

      it "replaces temporal context with timezone information" do
        timezone = "America/New_York"
        user.user_option.update!(timezone: timezone)
        freeze_time "2024-01-01 12:00:00"

        subject.localize_prompt!(prompt, user)

        content = prompt.messages[0][:content]

        expect(content).to include(%("timezone":"America/New_York"))
      end

      it "uses UTC as default timezone when user timezone is not set" do
        user.user_option.update!(timezone: nil)

        freeze_time "2024-01-01 12:00:00" do
          subject.localize_prompt!(prompt, user)

          parsed_context = JSON.parse(prompt.messages[0][:content].match(/context: (.+)$/)[1])
          expect(parsed_context["user"]["timezone"]).to eq("UTC")
        end
      end

      it "does not replace temporal context when user is nil" do
        prompt_content = prompt.messages[0][:content].dup
        subject.localize_prompt!(prompt, nil)
        expect(prompt.messages[0][:content]).to eq(prompt_content)
      end
    end
  end

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
          DiscourseAi::Completions::Llm.with_prepared_responses([english_text]) do
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
          DiscourseAi::Completions::Llm.with_prepared_responses([titles]) do
            subject.generate_and_send_prompt(prompt, english_text, user)
          end

        expect(response[:suggestions]).to contain_exactly(*expected)
      end
    end
  end
end
