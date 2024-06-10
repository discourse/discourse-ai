import { module, test } from "qunit";
import AiPersona from "discourse/plugins/discourse-ai/discourse/admin/models/ai-persona";

module("Discourse AI | Unit | Model | ai-persona", function () {
  test("init properties", function (assert) {
    const properties = {
      tools: [
        ["ToolName", { option1: "value1", option2: "value2" }],
        "ToolName2",
        "ToolName3",
      ],
    };

    const aiPersona = AiPersona.create(properties);

    assert.deepEqual(aiPersona.tools, ["ToolName", "ToolName2", "ToolName3"]);
    assert.equal(
      aiPersona.getToolOption("ToolName", "option1").value,
      "value1"
    );
    assert.equal(
      aiPersona.getToolOption("ToolName", "option2").value,
      "value2"
    );
  });

  test("update properties", function (assert) {
    const properties = {
      id: 1,
      name: "Test",
      tools: ["ToolName"],
      allowed_group_ids: [12],
      system: false,
      enabled: true,
      system_prompt: "System Prompt",
      priority: false,
      description: "Description",
      top_p: 0.8,
      temperature: 0.7,
      mentionable: false,
      default_llm: "Default LLM",
      user: null,
      user_id: null,
      max_context_posts: 5,
      vision_enabled: true,
      vision_max_pixels: 100,
      rag_uploads: [],
      rag_chunk_tokens: 374,
      rag_chunk_overlap_tokens: 10,
      rag_conversation_chunks: 10,
      question_consolidator_llm: "Question Consolidator LLM",
      allow_chat: false,
    };

    const aiPersona = AiPersona.create({ ...properties });

    aiPersona.getToolOption("ToolName", "option1").value = "value1";

    const updatedProperties = aiPersona.updateProperties();

    // perform remapping for save
    properties.tools = [["ToolName", { option1: "value1" }]];

    assert.deepEqual(updatedProperties, properties);
  });

  test("create properties", function (assert) {
    const properties = {
      id: 1,
      name: "Test",
      tools: ["ToolName"],
      allowed_group_ids: [12],
      system: false,
      enabled: true,
      system_prompt: "System Prompt",
      priority: false,
      description: "Description",
      top_p: 0.8,
      temperature: 0.7,
      user: null,
      user_id: null,
      default_llm: "Default LLM",
      mentionable: false,
      max_context_posts: 5,
      vision_enabled: true,
      vision_max_pixels: 100,
      rag_uploads: [],
      rag_chunk_tokens: 374,
      rag_chunk_overlap_tokens: 10,
      rag_conversation_chunks: 10,
      question_consolidator_llm: "Question Consolidator LLM",
      allow_chat: false,
    };

    const aiPersona = AiPersona.create({ ...properties });

    aiPersona.getToolOption("ToolName", "option1").value = "value1";

    const createdProperties = aiPersona.createProperties();

    properties.tools = [["ToolName", { option1: "value1" }]];

    assert.deepEqual(createdProperties, properties);
  });

  test("working copy", function (assert) {
    const aiPersona = AiPersona.create({
      name: "Test",
      tools: ["ToolName"],
    });

    aiPersona.getToolOption("ToolName", "option1").value = "value1";

    const workingCopy = aiPersona.workingCopy();

    assert.equal(workingCopy.name, "Test");
    assert.equal(
      workingCopy.getToolOption("ToolName", "option1").value,
      "value1"
    );
    assert.deepEqual(workingCopy.tools, ["ToolName"]);
  });
});
