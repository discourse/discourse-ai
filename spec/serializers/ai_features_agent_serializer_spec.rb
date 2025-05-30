# frozen_string_literal: true

RSpec.describe AiFeaturesAgentSerializer do
  fab!(:admin)
  fab!(:ai_agent)
  fab!(:group)
  fab!(:group_2) { Fabricate(:group) }

  describe "serialized attributes" do
    before do
      ai_agent.allowed_group_ids = [group.id, group_2.id]
      ai_agent.save!
    end

    context "when there is a agent with allowed groups" do
      let(:allowed_groups) do
        Group
          .where(id: ai_agent.allowed_group_ids)
          .pluck(:id, :name)
          .map { |id, name| { id: id, name: name } }
      end

      it "display every participant" do
        serialized = described_class.new(ai_agent, scope: Guardian.new(admin), root: nil)
        expect(serialized.id).to eq(ai_agent.id)
        expect(serialized.name).to eq(ai_agent.name)
        expect(serialized.system_prompt).to eq(ai_agent.system_prompt)
        expect(serialized.allowed_groups).to eq(allowed_groups)
        expect(serialized.enabled).to eq(ai_agent.enabled)
      end
    end
  end
end
