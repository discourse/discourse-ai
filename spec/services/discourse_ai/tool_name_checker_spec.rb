# frozen_string_literal: true

describe DiscourseAi::ToolNameChecker do
  describe "#check" do
    context "when the tool name is alphanumeric" do
      %w[toolname tool_name tool123].each do |tool_name|
        it "checks the name availability" do
          expect(DiscourseAi::ToolNameChecker.new(tool_name).check).to eq({ available: true })
        end
      end
    end

    context "when the tool name is not alphanumeric" do
      ["tool name", "tool-name", "tool@name"].each do |tool_name|
        it "returns an error" do
          expect(DiscourseAi::ToolNameChecker.new(tool_name).check).to eq(
            { available: false, errors: [I18n.t("discourse_ai.tools.name.characters")] },
          )
        end
      end
    end

    context "when the tool name is already" do
      let(:tool_name) { "toolname" }

      before { Fabricate(:ai_tool, tool_name: tool_name) }

      it "returns an error" do
        expect(DiscourseAi::ToolNameChecker.new(tool_name).check).to eq(
          { available: false, errors: [I18n.t("errors.messages.taken")] },
        )
      end
    end
  end
end
