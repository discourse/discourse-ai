# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Personas::Researcher do
  let :researcher do
    subject
  end

  it "renders schema" do
    expect(researcher.tools).to eq([DiscourseAi::AiBot::Tools::Google])
  end
end
