# frozen_string_literal: true

RSpec.describe Jobs::DigestRagUpload do
  fab!(:persona) { Fabricate(:ai_persona) }
  fab!(:upload)

  let(:document_file) { StringIO.new("some text" * 200) }

  let(:truncation) { DiscourseAi::Embeddings::Strategies::Truncation.new }
  let(:vector_rep) do
    DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(truncation)
  end

  let(:expected_embedding) { [0.0038493] * vector_rep.dimensions }

  let(:document_with_metadata) { plugin_file_from_fixtures("doc_with_metadata.txt", "rag") }

  let(:parsed_document_with_metadata) do
    plugin_file_from_fixtures("parsed_doc_with_metadata.txt", "rag")
  end

  let(:upload_with_metadata) do
    UploadCreator.new(document_with_metadata, "document.txt").create_for(Discourse.system_user.id)
  end

  before do
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com"
    SiteSetting.ai_embeddings_model = "bge-large-en"
    SiteSetting.authorized_extensions = "txt"

    WebMock.stub_request(
      :post,
      "#{SiteSetting.ai_embeddings_discourse_service_api_endpoint}/api/v1/classify",
    ).to_return(status: 200, body: JSON.dump(expected_embedding))
  end

  describe "#execute" do
    context "when processing an upload containing metadata" do
      it "correctly splits on metadata boundary" do
        # be explicit here about chunking strategy
        persona.update!(rag_chunk_tokens: 100, rag_chunk_overlap_tokens: 10)

        described_class.new.execute(upload_id: upload_with_metadata.id, ai_persona_id: persona.id)

        parsed = +""
        first = true
        RagDocumentFragment
          .where(upload: upload_with_metadata)
          .order(:fragment_number)
          .each do |fragment|
            parsed << "\n\n" if !first
            parsed << "metadata: #{fragment.metadata}\n"
            parsed << "number: #{fragment.fragment_number}\n"
            parsed << fragment.fragment
            first = false
          end

        # to rebuild parsed
        # File.write("/tmp/testing", parsed)

        expect(parsed).to eq(parsed_document_with_metadata.read)
      end
    end
    context "when processing an upload for the first time" do
      before { File.expects(:open).returns(document_file) }

      it "splits an upload into chunks" do
        subject.execute(upload_id: upload.id, ai_persona_id: persona.id)

        created_fragment = RagDocumentFragment.last

        expect(created_fragment).to be_present
        expect(created_fragment.fragment).to be_present
        expect(created_fragment.fragment_number).to eq(2)
      end

      it "queue jobs to generate embeddings for each fragment" do
        expect { subject.execute(upload_id: upload.id, ai_persona_id: persona.id) }.to change(
          Jobs::GenerateRagEmbeddings.jobs,
          :size,
        ).by(1)
      end
    end

    it "doesn't generate new fragments if we already processed the upload" do
      Fabricate(:rag_document_fragment, upload: upload, ai_persona: persona)
      previous_count = RagDocumentFragment.where(upload: upload, ai_persona: persona).count

      subject.execute(upload_id: upload.id, ai_persona_id: persona.id)
      updated_count = RagDocumentFragment.where(upload: upload, ai_persona: persona).count

      expect(updated_count).to eq(previous_count)
    end
  end
end
