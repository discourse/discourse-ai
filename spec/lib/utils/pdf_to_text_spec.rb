# frozen_string_literal: true

RSpec.describe DiscourseAi::Utils::PdfToText do
  fab!(:llm_model)
  fab!(:user)
  let(:pdf) { plugin_file_from_fixtures("2-page.pdf", "rag") }
  let(:upload) { UploadCreator.new(pdf, "2-page.pdf").create_for(Discourse.system_user.id) }
  before { SiteSetting.authorized_extensions = "pdf|png|jpg|jpeg" }

  describe "#extract_text" do
    it "extracts text from PDF pages" do
      pdf_to_text = described_class.new(upload: upload)
      pages = []
      pdf_to_text.extract_text { |page| pages << page }

      expect(pages).to eq(["Page 1", "Page 2"])
    end
  end

  context "when improving PDF extraction with LLM" do
    it "works as expected" do
      pdf_to_text = described_class.new(upload: upload, user: user, llm_model: llm_model)
      pages = []

      responses = [
        "<chunk>Page 1: LLM chunk 1</chunk><chunk>Page 1: LLM chunk 2</chunk>",
        "<chunk>Page 2: LLM chunk 3</chunk>",
      ]

      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do |_, _, _prompts|
        pdf_to_text.extract_text { |page| pages << page }
      end

      expect(pages).to eq(["Page 1: LLM chunk 1", "Page 1: LLM chunk 2", "Page 2: LLM chunk 3"])
    end
  end
end
