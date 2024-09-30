# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::RagDocumentFragmentsController do
  fab!(:admin)
  fab!(:ai_persona)

  before do
    sign_in(admin)

    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com"
  end

  describe "GET #indexing_status_check" do
    it "works for AiPersona" do
      get "/admin/plugins/discourse-ai/rag-document-fragments/files/status.json?target_type=AiPersona&target_id=#{ai_persona.id}"

      expect(response.parsed_body).to eq({})
      expect(response.status).to eq(200)
    end
  end

  describe "POST #upload_file" do
    it "works" do
      post "/admin/plugins/discourse-ai/rag-document-fragments/files/upload.json",
           params: {
             file: Rack::Test::UploadedFile.new(file_from_fixtures("spec.txt", "md")),
           }

      expect(response.status).to eq(200)

      upload = Upload.last
      expect(upload.original_filename).to end_with("spec.txt")
    end
  end
end
