# frozen_string_literal: true

module ::DiscourseAi
  module AiBot
    describe AnthropicBot do
      def bot_user
        User.find(EntryPoint::CLAUDE_V2_ID)
      end

      before do
        SiteSetting.ai_bot_enabled_chat_bots = "claude-2"
        SiteSetting.ai_bot_enabled = true
      end

      let(:bot) { described_class.new(bot_user) }
      fab!(:post)

      describe "system message" do
        it "includes the full command framework" do
          prompt = bot.system_prompt(post, allow_commands: true)

          expect(prompt).to include("read")
          expect(prompt).to include("search_query")
        end
      end

      it "does not include half parsed function calls in reply" do
        completion1 = "<function"
        completion2 = <<~REPLY
          _calls>
          <invoke>
          <tool_name>search</tool_name>
          <parameters>
          <search_query>hello world</search_query>
          </parameters>
          </invoke>
          </function_calls>
          junk
        REPLY

        completion1 = { completion: completion1 }.to_json
        completion2 = { completion: completion2 }.to_json

        completion3 = { completion: "<func" }.to_json

        request_number = 0

        last_body = nil

        stub_request(:post, "https://api.anthropic.com/v1/complete").with(
          body:
            lambda do |body|
              last_body = body
              request_number == 2
            end,
        ).to_return(status: 200, body: lambda { |request| +"data: #{completion3}" })

        stub_request(:post, "https://api.anthropic.com/v1/complete").with(
          body:
            lambda do |body|
              request_number += 1
              request_number == 1
            end,
        ).to_return(
          status: 200,
          body: lambda { |request| +"data: #{completion1}\ndata: #{completion2}" },
        )

        bot.reply_to(post)

        post.topic.reload

        raw = post.topic.ordered_posts.last.raw

        prompt = JSON.parse(last_body)["prompt"]

        # function call is bundled into Assitant prompt
        expect(prompt.split("Human:").length).to eq(2)

        # this should be stripped
        expect(prompt).not_to include("junk")

        expect(raw).to end_with("<func")

        # leading <function_call> should be stripped
        expect(raw).to start_with("\n\n<details")
      end

      it "does not include Assistant: in front of the system prompt" do
        prompt = nil

        stub_request(:post, "https://api.anthropic.com/v1/complete").with(
          body:
            lambda do |body|
              json = JSON.parse(body)
              prompt = json["prompt"]
              true
            end,
        ).to_return(
          status: 200,
          body: lambda { |request| +"data: " << { completion: "Hello World" }.to_json },
        )

        bot.reply_to(post)

        expect(prompt).not_to be_nil
        expect(prompt).not_to start_with("Assistant:")
      end

      describe "parsing a reply prompt" do
        it "can correctly predict that a completion needs to be cancelled" do
          functions = DiscourseAi::AiBot::Bot::FunctionCalls.new

          # note anthropic API has a silly leading space, we need to make sure we can handle that
          prompt = +<<~REPLY.strip
            <function_calls>
            <invoke>
            <tool_name>search</tool_name>
            <parameters>
            <search_query>hello world</search_query>
            <random_stuff>77</random_stuff>
            </parameters>
            </invoke>
            </function_calls
          REPLY

          bot.populate_functions(
            partial: nil,
            reply: prompt,
            functions: functions,
            done: false,
            current_delta: "",
          )

          expect(functions.found?).to eq(true)
          expect(functions.cancel_completion?).to eq(false)

          prompt << ">"

          bot.populate_functions(
            partial: nil,
            reply: prompt,
            functions: functions,
            done: true,
            current_delta: "",
          )

          expect(functions.found?).to eq(true)

          expect(functions.to_a.length).to eq(1)

          expect(functions.to_a).to eq(
            [{ name: "search", arguments: "{\"search_query\":\"hello world\"}" }],
          )
        end
      end

      describe "#update_with_delta" do
        describe "get_delta" do
          it "can properly remove first leading space" do
            context = {}
            reply = +""

            reply << bot.get_delta({ completion: " Hello" }, context)
            reply << bot.get_delta({ completion: " World" }, context)
            expect(reply).to eq("Hello World")
          end

          it "can properly remove Assistant prefix" do
            context = {}
            reply = +""

            reply << bot.get_delta({ completion: "Hello " }, context)
            expect(reply).to eq("Hello ")

            reply << bot.get_delta({ completion: "world" }, context)
            expect(reply).to eq("Hello world")
          end
        end
      end
    end
  end
end
