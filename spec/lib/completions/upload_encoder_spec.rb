# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::UploadEncoder do
  let(:file) { plugin_file_from_fixtures("1x1.gif") }

  it "automatically converts gifs to pngs" do
    upload = UploadCreator.new(file, "1x1.gif").create_for(Discourse.system_user.id)
    encoded = described_class.encode(upload_ids: [upload.id], max_pixels: 1_048_576)
    expect(encoded.length).to eq(1)
    expect(encoded[0][:base64]).to be_present
    expect(encoded[0][:mime_type]).to eq("image/png")
  end
end
