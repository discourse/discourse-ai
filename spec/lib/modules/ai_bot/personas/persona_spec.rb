#frozen_string_literal: true

class TestPersona < DiscourseAi::AiBot::Personas::Persona
  def tools
    [
      DiscourseAi::AiBot::Tools::ListTags,
      DiscourseAi::AiBot::Tools::Search,
      DiscourseAi::AiBot::Tools::Image,
    ]
  end

  def system_prompt
    <<~PROMPT
      {site_url}
      {site_title}
      {site_description}
      {participants}
      {time}
    PROMPT
  end
end

RSpec.describe DiscourseAi::AiBot::Personas::Persona do
  let :persona do
    TestPersona.new
  end

  let :topic_with_users do
    topic = Topic.new
    topic.allowed_users = [User.new(username: "joe"), User.new(username: "jane")]
    topic
  end

  after do
    # we are rolling back transactions so we can create poison cache
    AiPersona.persona_cache.flush!
  end

  let(:context) do
    {
      site_url: Discourse.base_url,
      site_title: "test site title",
      site_description: "test site description",
      time: Time.zone.now,
      participants: topic_with_users.allowed_users.map(&:username).join(", "),
    }
  end

  fab!(:admin)
  fab!(:user)
  fab!(:upload)

  it "renders the system prompt" do
    freeze_time

    rendered = persona.craft_prompt(context)
    system_message = rendered.messages.first[:content]

    expect(system_message).to include(Discourse.base_url)
    expect(system_message).to include("test site title")
    expect(system_message).to include("test site description")
    expect(system_message).to include("joe, jane")
    expect(system_message).to include(Time.zone.now.to_s)

    tools = rendered.tools

    expect(tools.find { |t| t[:name] == "search" }).to be_present
    expect(tools.find { |t| t[:name] == "tags" }).to be_present

    # needs to be configured so it is not available
    expect(tools.find { |t| t[:name] == "image" }).to be_nil
  end

  it "can parse string that are wrapped in quotes" do
    SiteSetting.ai_stability_api_key = "123"

    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "image",
        id: "call_JtYQMful5QKqw97XFsHzPweB",
        parameters: {
          prompts: ["cat oil painting", "big car"],
          aspect_ratio: "16:9",
        },
      )

    tool_instance =
      DiscourseAi::AiBot::Personas::Artist.new.find_tool(
        tool_call,
        bot_user: nil,
        llm: nil,
        context: nil,
      )

    expect(tool_instance.parameters[:prompts]).to eq(["cat oil painting", "big car"])
    expect(tool_instance.parameters[:aspect_ratio]).to eq("16:9")
  end

  it "enforces enums" do
    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "search",
        id: "call_JtYQMful5QKqw97XFsHzPweB",
        parameters: {
          max_posts: "3.2",
          status: "cow",
          foo: "bar",
        },
      )

    tool_instance =
      DiscourseAi::AiBot::Personas::General.new.find_tool(
        tool_call,
        bot_user: nil,
        llm: nil,
        context: nil,
      )

    expect(tool_instance.parameters.key?(:status)).to eq(false)

    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "search",
        id: "call_JtYQMful5QKqw97XFsHzPweB",
        parameters: {
          max_posts: "3.2",
          status: "open",
          foo: "bar",
        },
      )

    tool_instance =
      DiscourseAi::AiBot::Personas::General.new.find_tool(
        tool_call,
        bot_user: nil,
        llm: nil,
        context: nil,
      )

    expect(tool_instance.parameters[:status]).to eq("open")
  end

  it "can coerce integers" do
    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "search",
        id: "call_JtYQMful5QKqw97XFsHzPweB",
        parameters: {
          max_posts: "3.2",
          search_query: "hello world",
          foo: "bar",
        },
      )

    search =
      DiscourseAi::AiBot::Personas::General.new.find_tool(
        tool_call,
        bot_user: nil,
        llm: nil,
        context: nil,
      )

    expect(search.parameters[:max_posts]).to eq(3)
    expect(search.parameters[:search_query]).to eq("hello world")
    expect(search.parameters.key?(:foo)).to eq(false)
  end

  it "can correctly parse arrays in tools" do
    SiteSetting.ai_openai_api_key = "123"

    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "dall_e",
        id: "call_JtYQMful5QKqw97XFsHzPweB",
        parameters: {
          prompts: ["cat oil painting", "big car"],
        },
      )

    tool_instance =
      DiscourseAi::AiBot::Personas::DallE3.new.find_tool(
        tool_call,
        bot_user: nil,
        llm: nil,
        context: nil,
      )
    expect(tool_instance.parameters[:prompts]).to eq(["cat oil painting", "big car"])
  end

  describe "custom personas" do
    it "is able to find custom personas" do
      Group.refresh_automatic_groups!

      # define an ai persona everyone can see
      persona =
        AiPersona.create!(
          name: "zzzpun_bot",
          description: "you write puns",
          system_prompt: "you are pun bot",
          tools: ["Image"],
          allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        )

      custom_persona = DiscourseAi::AiBot::Personas::Persona.all(user: user).last
      expect(custom_persona.name).to eq("zzzpun_bot")
      expect(custom_persona.description).to eq("you write puns")

      instance = custom_persona.new
      expect(instance.tools).to eq([DiscourseAi::AiBot::Tools::Image])
      expect(instance.craft_prompt(context).messages.first[:content]).to eq("you are pun bot")

      # should update
      persona.update!(name: "zzzpun_bot2")
      custom_persona = DiscourseAi::AiBot::Personas::Persona.all(user: user).last
      expect(custom_persona.name).to eq("zzzpun_bot2")

      # can be disabled
      persona.update!(enabled: false)
      last_persona = DiscourseAi::AiBot::Personas::Persona.all(user: user).last
      expect(last_persona.name).not_to eq("zzzpun_bot2")

      persona.update!(enabled: true)
      # no groups have access
      persona.update!(allowed_group_ids: [])

      last_persona = DiscourseAi::AiBot::Personas::Persona.all(user: user).last
      expect(last_persona.name).not_to eq("zzzpun_bot2")
    end
  end

  describe "available personas" do
    it "includes all personas by default" do
      Group.refresh_automatic_groups!

      # must be enabled to see it
      SiteSetting.ai_stability_api_key = "abc"
      SiteSetting.ai_google_custom_search_api_key = "abc"
      SiteSetting.ai_google_custom_search_cx = "abc123"

      # should be ordered by priority and then alpha
      expect(DiscourseAi::AiBot::Personas::Persona.all(user: user)).to eq(
        [
          DiscourseAi::AiBot::Personas::General,
          DiscourseAi::AiBot::Personas::Artist,
          DiscourseAi::AiBot::Personas::Creative,
          DiscourseAi::AiBot::Personas::DiscourseHelper,
          DiscourseAi::AiBot::Personas::GithubHelper,
          DiscourseAi::AiBot::Personas::Researcher,
          DiscourseAi::AiBot::Personas::SettingsExplorer,
          DiscourseAi::AiBot::Personas::SqlHelper,
        ],
      )

      # it should allow staff access to WebArtifactCreator
      expect(DiscourseAi::AiBot::Personas::Persona.all(user: admin)).to eq(
        [
          DiscourseAi::AiBot::Personas::General,
          DiscourseAi::AiBot::Personas::Artist,
          DiscourseAi::AiBot::Personas::Creative,
          DiscourseAi::AiBot::Personas::DiscourseHelper,
          DiscourseAi::AiBot::Personas::GithubHelper,
          DiscourseAi::AiBot::Personas::Researcher,
          DiscourseAi::AiBot::Personas::SettingsExplorer,
          DiscourseAi::AiBot::Personas::SqlHelper,
          DiscourseAi::AiBot::Personas::WebArtifactCreator,
        ],
      )

      # omits personas if key is missing
      SiteSetting.ai_stability_api_key = ""
      SiteSetting.ai_google_custom_search_api_key = ""
      SiteSetting.ai_artifact_security = "disabled"

      expect(DiscourseAi::AiBot::Personas::Persona.all(user: admin)).to contain_exactly(
        DiscourseAi::AiBot::Personas::General,
        DiscourseAi::AiBot::Personas::SqlHelper,
        DiscourseAi::AiBot::Personas::SettingsExplorer,
        DiscourseAi::AiBot::Personas::Creative,
        DiscourseAi::AiBot::Personas::DiscourseHelper,
        DiscourseAi::AiBot::Personas::GithubHelper,
      )

      AiPersona.find(
        DiscourseAi::AiBot::Personas::Persona.system_personas[
          DiscourseAi::AiBot::Personas::General
        ],
      ).update!(enabled: false)

      expect(DiscourseAi::AiBot::Personas::Persona.all(user: user)).to contain_exactly(
        DiscourseAi::AiBot::Personas::SqlHelper,
        DiscourseAi::AiBot::Personas::SettingsExplorer,
        DiscourseAi::AiBot::Personas::Creative,
        DiscourseAi::AiBot::Personas::DiscourseHelper,
        DiscourseAi::AiBot::Personas::GithubHelper,
      )
    end
  end

  describe "#craft_prompt" do
    before do
      Group.refresh_automatic_groups!
      SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com"
      SiteSetting.ai_embeddings_enabled = true
    end

    let(:ai_persona) { DiscourseAi::AiBot::Personas::Persona.all(user: user).first.new }

    let(:with_cc) do
      context.merge(conversation_context: [{ content: "Tell me the time", type: :user }])
    end

    context "when a persona has no uploads" do
      it "doesn't include RAG guidance" do
        guidance_fragment =
          "The following texts will give you additional guidance to elaborate a response."

        expect(ai_persona.craft_prompt(with_cc).messages.first[:content]).not_to include(
          guidance_fragment,
        )
      end
    end

    context "when RAG is running with a question consolidator" do
      let(:consolidated_question) { "what is the time in france?" }

      fab!(:llm_model) { Fabricate(:fake_model) }

      it "will run the question consolidator" do
        strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
        vector_rep =
          DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)
        context_embedding = vector_rep.dimensions.times.map { rand(-1.0...1.0) }
        EmbeddingsGenerationStubs.discourse_service(
          SiteSetting.ai_embeddings_model,
          consolidated_question,
          context_embedding,
        )

        custom_ai_persona =
          Fabricate(
            :ai_persona,
            name: "custom",
            rag_conversation_chunks: 3,
            allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
            question_consolidator_llm: "custom:#{llm_model.id}",
          )

        UploadReference.ensure_exist!(target: custom_ai_persona, upload_ids: [upload.id])

        custom_persona =
          DiscourseAi::AiBot::Personas::Persona.find_by(id: custom_ai_persona.id, user: user).new

        # this means that we will consolidate
        ctx =
          with_cc.merge(
            conversation_context: [
              { content: "Tell me the time", type: :user },
              { content: "the time is 1", type: :model },
              { content: "in france?", type: :user },
            ],
          )

        DiscourseAi::Completions::Endpoints::Fake.with_fake_content(consolidated_question) do
          custom_persona.craft_prompt(ctx).messages.first[:content]
        end

        message =
          DiscourseAi::Completions::Endpoints::Fake.last_call[:dialect].prompt.messages.last[
            :content
          ]
        expect(message).to include("Tell me the time")
        expect(message).to include("the time is 1")
        expect(message).to include("in france?")
      end
    end

    context "when a persona has RAG uploads" do
      def stub_fragments(limit, expected_limit: nil)
        candidate_ids = []

        limit.times do |i|
          candidate_ids << Fabricate(
            :rag_document_fragment,
            fragment: "fragment-n#{i}",
            target_id: ai_persona.id,
            target_type: "AiPersona",
            upload: upload,
          ).id
        end

        DiscourseAi::Embeddings::VectorRepresentations::BgeLargeEn
          .any_instance
          .expects(:asymmetric_rag_fragment_similarity_search)
          .with { |args, kwargs| kwargs[:limit] == (expected_limit || limit) }
          .returns(candidate_ids)
      end

      before do
        stored_ai_persona = AiPersona.find(ai_persona.id)
        UploadReference.ensure_exist!(target: stored_ai_persona, upload_ids: [upload.id])

        context_embedding = [0.049382, 0.9999]
        EmbeddingsGenerationStubs.discourse_service(
          SiteSetting.ai_embeddings_model,
          with_cc.dig(:conversation_context, 0, :content),
          context_embedding,
        )
      end

      context "when persona allows for less fragments" do
        before { stub_fragments(3) }

        it "will only pick 3 fragments" do
          custom_ai_persona =
            Fabricate(
              :ai_persona,
              name: "custom",
              rag_conversation_chunks: 3,
              allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
            )

          UploadReference.ensure_exist!(target: custom_ai_persona, upload_ids: [upload.id])

          custom_persona =
            DiscourseAi::AiBot::Personas::Persona.find_by(id: custom_ai_persona.id, user: user).new

          expect(custom_persona.class.rag_conversation_chunks).to eq(3)

          crafted_system_prompt = custom_persona.craft_prompt(with_cc).messages.first[:content]

          expect(crafted_system_prompt).to include("fragment-n0")
          expect(crafted_system_prompt).to include("fragment-n1")
          expect(crafted_system_prompt).to include("fragment-n2")
          expect(crafted_system_prompt).not_to include("fragment-n3")
        end
      end

      context "when the reranker is available" do
        before do
          SiteSetting.ai_hugging_face_tei_reranker_endpoint = "https://test.reranker.com"

          # hard coded internal implementation, reranker takes x5 number of chunks
          stub_fragments(15, expected_limit: 50) # Mimic limit being more than 10 results
        end

        it "uses the re-ranker to reorder the fragments and pick the top 10 candidates" do
          skip "This test is flaky needs to be investigated ordering does not come back as expected"
          expected_reranked = (0..14).to_a.reverse.map { |idx| { index: idx } }

          WebMock.stub_request(:post, "https://test.reranker.com/rerank").to_return(
            status: 200,
            body: JSON.dump(expected_reranked),
          )

          crafted_system_prompt = ai_persona.craft_prompt(with_cc).messages.first[:content]

          expect(crafted_system_prompt).to include("fragment-n14")
          expect(crafted_system_prompt).to include("fragment-n13")
          expect(crafted_system_prompt).to include("fragment-n12")
          expect(crafted_system_prompt).not_to include("fragment-n4") # Fragment #11 not included
        end
      end

      context "when the reranker is not available" do
        before { stub_fragments(10) }

        it "picks the first 10 candidates from the similarity search" do
          crafted_system_prompt = ai_persona.craft_prompt(with_cc).messages.first[:content]

          expect(crafted_system_prompt).to include("fragment-n0")
          expect(crafted_system_prompt).to include("fragment-n1")
          expect(crafted_system_prompt).to include("fragment-n2")

          expect(crafted_system_prompt).not_to include("fragment-n10") # Fragment #10 not included
        end
      end
    end
  end
end
