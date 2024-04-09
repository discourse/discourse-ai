# frozen_string_literal: true

RSpec.describe RagDocumentFragment do
  fab!(:persona) { Fabricate(:ai_persona) }
  fab!(:upload_1) { Fabricate(:upload) }
  fab!(:upload_2) { Fabricate(:upload) }

  before do
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com"
  end

  describe ".link_uploads_and_persona" do
    it "does nothing if there is no persona" do
      expect { described_class.link_persona_and_uploads(nil, [upload_1.id]) }.not_to change(
        Jobs::DigestRagUpload.jobs,
        :size,
      )
    end

    it "does nothing if there are no uploads" do
      expect { described_class.link_persona_and_uploads(persona, []) }.not_to change(
        Jobs::DigestRagUpload.jobs,
        :size,
      )
    end

    it "queues a job for each upload to generate fragments" do
      expect {
        described_class.link_persona_and_uploads(persona, [upload_1.id, upload_2.id])
      }.to change(Jobs::DigestRagUpload.jobs, :size).by(2)
    end

    it "creates references between the persona an each upload" do
      described_class.link_persona_and_uploads(persona, [upload_1.id, upload_2.id])

      refs = UploadReference.where(target: persona).pluck(:upload_id)

      expect(refs).to contain_exactly(upload_1.id, upload_2.id)
    end
  end

  describe ".update_persona_uploads" do
    it "does nothing if there is no persona" do
      expect { described_class.update_persona_uploads(nil, [upload_1.id]) }.not_to change(
        Jobs::DigestRagUpload.jobs,
        :size,
      )
    end

    it "deletes the fragment if its not present in the uploads list" do
      fragment = Fabricate(:rag_document_fragment, ai_persona: persona)

      described_class.update_persona_uploads(persona, [])

      expect { fragment.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "delete references between the upload and the persona" do
      described_class.link_persona_and_uploads(persona, [upload_1.id, upload_2.id])

      described_class.update_persona_uploads(persona, [upload_2.id])

      refs = UploadReference.where(target: persona).pluck(:upload_id)

      expect(refs).to contain_exactly(upload_2.id)
    end

    it "queues jobs to generate new fragments" do
      expect { described_class.update_persona_uploads(persona, [upload_1.id]) }.to change(
        Jobs::DigestRagUpload.jobs,
        :size,
      ).by(1)
    end
  end

  describe ".indexing_status" do
    let(:truncation) { DiscourseAi::Embeddings::Strategies::Truncation.new }
    let(:vector_rep) do
      DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(truncation)
    end

    fab!(:rag_document_fragment_1) do
      Fabricate(:rag_document_fragment, upload: upload_1, ai_persona: persona)
    end

    fab!(:rag_document_fragment_2) do
      Fabricate(:rag_document_fragment, upload: upload_1, ai_persona: persona)
    end

    let(:expected_embedding) { [0.0038493] * vector_rep.dimensions }

    before do
      SiteSetting.ai_embeddings_enabled = true
      SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com"

      WebMock.stub_request(
        :post,
        "#{SiteSetting.ai_embeddings_discourse_service_api_endpoint}/api/v1/classify",
      ).to_return(status: 200, body: JSON.dump(expected_embedding))

      vector_rep.generate_representation_from(rag_document_fragment_1)
    end

    it "returns total, indexed and unindexed fragments for each upload" do
      results = described_class.indexing_status(persona, [upload_1, upload_2])

      upload_1_status = results[upload_1.id]
      expect(upload_1_status[:total]).to eq(2)
      expect(upload_1_status[:indexed]).to eq(1)
      expect(upload_1_status[:left]).to eq(1)

      upload_1_status = results[upload_2.id]
      expect(upload_1_status[:total]).to eq(0)
      expect(upload_1_status[:indexed]).to eq(0)
      expect(upload_1_status[:left]).to eq(0)
    end
  end
end
