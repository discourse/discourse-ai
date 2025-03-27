# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Researcher do
  let :researcher do
    subject
  end

  it "renders schema" do
    expect(researcher.tools).to eq(
      [DiscourseAi::Personas::Tools::Google, DiscourseAi::Personas::Tools::WebBrowser],
    )
  end
end
