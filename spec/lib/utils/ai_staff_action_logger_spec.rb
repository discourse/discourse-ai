# frozen_string_literal: true

RSpec.describe DiscourseAi::Utils::AiStaffActionLogger do
  fab!(:admin)
  fab!(:llm_model)
  fab!(:ai_persona)
  fab!(:group) { Fabricate(:group) }

  subject { described_class.new(admin) }

  describe "#log_creation" do
    it "logs creation of an entity with field configuration" do
      staff_action_logger = instance_double(StaffActionLogger)
      expect(StaffActionLogger).to receive(:new).with(admin).and_return(staff_action_logger)
      
      # Create field configuration
      field_config = {
        name: {},
        provider: {},
        url: {},
        api_key: { type: :sensitive }
      }
      
      # Create entity details
      entity_details = {
        model_id: llm_model.id,
        model_name: llm_model.name,
        display_name: llm_model.display_name
      }
      
      # Setup model with sensitive data
      llm_model.update!(api_key: "secret_key")
      
      expect(staff_action_logger).to receive(:log_custom).with(
        "create_ai_llm_model", 
        hash_including(
          "model_id" => llm_model.id,
          "name" => llm_model.name,
          "provider" => llm_model.provider,
          "url" => llm_model.url,
          "api_key" => "[FILTERED]"
        )
      )
      
      subject.log_creation("llm_model", llm_model, field_config, entity_details)
    end
    
    it "handles large text fields with type declaration" do
      staff_action_logger = instance_double(StaffActionLogger)
      expect(StaffActionLogger).to receive(:new).with(admin).and_return(staff_action_logger)
      
      # Create a persona with a large system prompt
      large_prompt = "a" * 200
      ai_persona.update!(system_prompt: large_prompt)
      
      # Create entity details
      entity_details = {
        persona_id: ai_persona.id,
        persona_name: ai_persona.name
      }
      
      field_config = {
        name: {},
        description: {},
        system_prompt: { type: :large_text }
      }
      
      # The log_details should include the truncated system_prompt
      expect(staff_action_logger).to receive(:log_custom).with(
        "create_ai_persona",
        hash_including(
          "persona_id" => ai_persona.id, 
          "name" => ai_persona.name,
          "system_prompt" => an_instance_of(String)
        )
      ) do |action, details|
        # Check that system_prompt was truncated
        expect(details["system_prompt"].length).to be < 200
      end
      
      subject.log_creation("persona", ai_persona, field_config, entity_details)
    end
    
    it "allows excluding fields from extraction" do
      staff_action_logger = instance_double(StaffActionLogger)
      expect(StaffActionLogger).to receive(:new).with(admin).and_return(staff_action_logger)
      
      field_config = {
        name: {},
        display_name: {},
        provider: { extract: false }, # Should be excluded
        url: {}
      }
      
      # Create entity details
      entity_details = {
        model_id: llm_model.id,
        model_name: llm_model.name,
        display_name: llm_model.display_name
      }
      
      expect(staff_action_logger).to receive(:log_custom).with(
        "create_ai_llm_model",
        hash_including(
          "model_id" => llm_model.id,
          "name" => llm_model.name,
          "display_name" => llm_model.display_name,
          "url" => llm_model.url
        )
      ) do |action, details|
        # Provider should not be present
        expect(details).not_to have_key("provider")
      end
      
      subject.log_creation("llm_model", llm_model, field_config, entity_details)
    end
  end
  
  describe "#log_update" do
    it "handles empty arrays and complex JSON properly" do
      staff_action_logger = instance_double(StaffActionLogger)
      expect(StaffActionLogger).to receive(:new).with(admin).and_return(staff_action_logger)
      
      # Setup initial attributes with empty JSON arrays
      initial_attributes = {
        "name" => "Old Name",
        "allowed_group_ids" => []
      }
      
      # Update with complex JSON
      ai_persona.update!(
        name: "New Name",
        allowed_group_ids: [group.id, 999]
      )
      
      field_config = {
        name: {},
        json_fields: %w[allowed_group_ids]
      }
      
      # It should log that allowed_group_ids was updated without showing the exact diff
      expect(staff_action_logger).to receive(:log_custom).with(
        "update_ai_persona",
        hash_including(
          "persona_id" => ai_persona.id,
          "persona_name" => ai_persona.name,
          "name" => "Old Name → New Name",
          "allowed_group_ids" => "updated"
        )
      )
      
      # Create entity details
      entity_details = {
        persona_id: ai_persona.id,
        persona_name: ai_persona.name
      }
      
      subject.log_update("persona", ai_persona, initial_attributes, field_config, entity_details)
    end
    
    it "logs changes to attributes based on field configuration" do
      staff_action_logger = instance_double(StaffActionLogger)
      expect(StaffActionLogger).to receive(:new).with(admin).and_return(staff_action_logger)
      
      initial_attributes = {
        "name" => "Old Name",
        "display_name" => "Old Display Name",
        "provider" => "open_ai",
        "api_key" => "old_secret"
      }
      
      llm_model.update!(
        name: "New Name",
        display_name: "New Display Name", 
        provider: "anthropic",
        api_key: "new_secret"
      )
      
      field_config = {
        name: {},
        display_name: {},
        provider: {},
        api_key: { type: :sensitive }
      }
      
      # Create entity details
      entity_details = {
        model_id: llm_model.id,
        model_name: llm_model.name,
        display_name: llm_model.display_name
      }
      
      # It should include changes with appropriate handling for sensitive data
      expect(staff_action_logger).to receive(:log_custom).with(
        "update_ai_llm_model",
        hash_including(
          "model_id" => llm_model.id,
          "name" => "Old Name → New Name",
          "display_name" => "Old Display Name → New Display Name",
          "provider" => "open_ai → anthropic",
          "api_key" => "updated" # Not showing actual values
        )
      )
      
      subject.log_update("llm_model", llm_model, initial_attributes, field_config, entity_details)
    end
    
    it "doesn't log when there are no changes" do
      staff_action_logger = instance_double(StaffActionLogger)
      expect(StaffActionLogger).to receive(:new).with(admin).and_return(staff_action_logger)
      
      initial_attributes = {
        "name" => llm_model.name,
        "display_name" => llm_model.display_name,
        "provider" => llm_model.provider
      }
      
      field_config = {
        name: {},
        display_name: {},
        provider: {}
      }
      
      # It should not call log_custom since there are no changes
      expect(staff_action_logger).not_to receive(:log_custom)
      
      # Create entity details
      entity_details = {
        model_id: llm_model.id,
        model_name: llm_model.name,
        display_name: llm_model.display_name
      }
      
      subject.log_update("llm_model", llm_model, initial_attributes, field_config, entity_details)
    end
    
    it "handles fields marked as not to be tracked" do
      staff_action_logger = instance_double(StaffActionLogger)
      expect(StaffActionLogger).to receive(:new).with(admin).and_return(staff_action_logger)
      
      initial_attributes = {
        "name" => "Old Name",
        "display_name" => "Old Display Name",
        "provider" => "open_ai"
      }
      
      llm_model.update!(
        name: "New Name",
        display_name: "New Display Name", 
        provider: "anthropic"
      )
      
      field_config = {
        name: {},
        display_name: {},
        provider: { track: false } # Should not be tracked even though it changed
      }
      
      # Provider should not appear in the logged changes
      expect(staff_action_logger).to receive(:log_custom).with(
        "update_ai_llm_model",
        hash_including(
          "model_id" => llm_model.id,
          "name" => "Old Name → New Name",
          "display_name" => "Old Display Name → New Display Name"
        )
      ) do |action, details|
        expect(details).not_to have_key("provider")
      end
      
      # Create entity details
      entity_details = {
        model_id: llm_model.id,
        model_name: llm_model.name,
        display_name: llm_model.display_name
      }
      
      subject.log_update("llm_model", llm_model, initial_attributes, field_config, entity_details)
    end
    
    it "handles json fields properly" do
      staff_action_logger = instance_double(StaffActionLogger)
      expect(StaffActionLogger).to receive(:new).with(admin).and_return(staff_action_logger)
      
      # Setup initial attributes with JSON fields
      initial_attributes = {
        "name" => "Old Name",
        "tools" => [["search", { "base_query" => "test" }, true]]
      }
      
      # Update with different JSON
      ai_persona.update!(
        name: "New Name",
        tools: [["search", { "base_query" => "updated" }, true], ["categories", {}, false]]
      )
      
      field_config = {
        name: {},
        json_fields: %w[tools]
      }
      
      # It should log that tools was updated without showing the exact diff
      expect(staff_action_logger).to receive(:log_custom).with(
        "update_ai_persona",
        hash_including(
          "persona_id" => ai_persona.id,
          "persona_name" => ai_persona.name,
          "name" => "Old Name → New Name",
          "tools" => "updated"
        )
      )
      
      # Create entity details
      entity_details = {
        persona_id: ai_persona.id,
        persona_name: ai_persona.name
      }
      
      subject.log_update("persona", ai_persona, initial_attributes, field_config, entity_details)
    end
  end
  
  describe "#log_deletion" do
    it "logs deletion with the correct entity type" do
      staff_action_logger = instance_double(StaffActionLogger)
      expect(StaffActionLogger).to receive(:new).with(admin).and_return(staff_action_logger)
      
      details = {
        model_id: llm_model.id,
        display_name: llm_model.display_name,
        name: llm_model.name
      }
      
      expect(staff_action_logger).to receive(:log_custom).with(
        "delete_ai_llm_model",
        hash_including(
          "model_id" => details[:model_id],
          "display_name" => details[:display_name],
          "name" => details[:name]
        )
      )
      
      subject.log_deletion("llm_model", details)
    end
  end
  
  describe "#log_custom" do
    it "delegates to StaffActionLogger#log_custom" do
      staff_action_logger = instance_double(StaffActionLogger)
      expect(StaffActionLogger).to receive(:new).with(admin).and_return(staff_action_logger)
      
      details = { key: "value" }
      
      expect(staff_action_logger).to receive(:log_custom).with(
        "custom_action_type",
        hash_including("key" => details[:key])
      )
      
      subject.log_custom("custom_action_type", details)
    end
  end
  
  describe "Special cases from controllers" do
    context "with LlmModel quotas" do
      before do
        # Create a quota for the model
        @quota = Fabricate(:llm_quota, llm_model: llm_model, group: group, max_tokens: 1000)
      end
      
      it "handles quota changes in log_llm_model_creation" do
        expect_any_instance_of(StaffActionLogger).to receive(:log_custom) do |_, action, details|
          expect(action).to eq("create_ai_llm_model")
          expect(details).to include("model_id", "model_name", "display_name")
          expect(details["quotas"]).to include("Group #{group.id}")
          expect(details["quotas"]).to include("1000 tokens")
        end

        # Call the method directly as it would be called from the controller
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(admin)
        field_config = { display_name: {}, name: {} }
        
        # Create entity details
        entity_details = {
          model_id: llm_model.id,
          model_name: llm_model.name,
          display_name: llm_model.display_name
        }
        
        log_details = entity_details.dup
        log_details.merge!(logger.send(:extract_entity_attributes, llm_model, field_config))
        
        # Add quota information as a special case
        log_details[:quotas] = llm_model.llm_quotas.map do |quota|
          "Group #{quota.group_id}: #{quota.max_tokens} tokens, #{quota.max_usages} usages, #{quota.duration_seconds}s"
        end.join("; ")
        
        logger.log_custom("create_ai_llm_model", log_details)
      end
      
      it "handles quota changes in log_llm_model_update" do
        initial_quotas = llm_model.llm_quotas.map(&:attributes)
        
        # Update the quota
        @quota.update!(max_tokens: 2000)
        current_quotas = llm_model.llm_quotas.reload.map(&:attributes)
        
        expect_any_instance_of(StaffActionLogger).to receive(:log_custom) do |_, action, details|
          expect(action).to eq("update_ai_llm_model")
          expect(details).to include("model_id", "quotas")
          expect(details["quotas"]).to include("1000 tokens")
          expect(details["quotas"]).to include("2000 tokens")
        end
        
        # Simulate the special quota handling in the controller
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(admin)
        changes = {}
        
        # Track quota changes separately as they're a special case
        if initial_quotas != current_quotas
          initial_quota_summary = initial_quotas.map { |q| "Group #{q['group_id']}: #{q['max_tokens']} tokens" }.join("; ")
          current_quota_summary = current_quotas.map { |q| "Group #{q['group_id']}: #{q['max_tokens']} tokens" }.join("; ")
          changes[:quotas] = "#{initial_quota_summary} → #{current_quota_summary}"
        end
        
        # Create entity details
        entity_details = {
          model_id: llm_model.id,
          model_name: llm_model.name,
          display_name: llm_model.display_name
        }
        
        log_details = entity_details.dup.merge(changes)
        logger.log_custom("update_ai_llm_model", log_details)
      end
    end
  end
end