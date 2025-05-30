# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Researcher do
  let :researcher do
    subject
  end

  it "renders schema" do
    expect(researcher.tools).to eq(
      [DiscourseAi::Agents::Tools::Google, DiscourseAi::Agents::Tools::WebBrowser],
    )
  end
end
