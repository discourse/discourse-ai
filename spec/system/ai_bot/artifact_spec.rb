# frozen_string_literal: true

RSpec.describe "AI Artifact with Data Attributes", type: :system do
  fab!(:admin)
  fab!(:user)
  fab!(:author) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category, user: admin, read_restricted: false) }
  fab!(:topic) { Fabricate(:topic, category: category, user: author) }
  fab!(:post) { Fabricate(:post, topic: topic, user: author) }

  before { SiteSetting.discourse_ai_enabled = true }

  it "correctly passes data attributes and user info to a public AI artifact embedded in a post" do
    artifact_js = <<~JS
      window.discourseArtifactReady.then(data => {
        const displayElement = document.getElementById('data-display');
        if (displayElement) {
          displayElement.innerText = JSON.stringify(data);
        }
      }).catch(err => {
        const displayElement = document.getElementById('data-display');
        if (displayElement) {
          displayElement.innerText = 'Error: ' + err.message;
        }
        console.error("Artifact JS Error:", err);
      });
    JS

    ai_artifact =
      Fabricate(
        :ai_artifact,
        user: author,
        name: "Data Passing Test Artifact",
        html: "<div id='data-display'>Waiting for data...</div>",
        js: artifact_js.strip,
        metadata: {
          public: true,
        },
      )

    raw_post_content =
      "<div class='ai-artifact' data-ai-artifact-id='#{ai_artifact.id}' data-custom-message='hello-from-post' data-post-author-id='#{author.id}'></div>"
    _post = Fabricate(:post, topic: topic, user: author, raw: raw_post_content)

    sign_in(user)
    visit "/t/#{topic.slug}/#{topic.id}"

    find(".ai-artifact__click-to-run button").click

    artifact_element_selector = ".ai-artifact[data-ai-artifact-id='#{ai_artifact.id}']"
    iframe_selector = "#{artifact_element_selector} iframe"

    expect(page).to have_css(iframe_selector)

    iframe_element = find(iframe_selector)
    expect(iframe_element["data-custom-message"]).to eq("hello-from-post")
    expect(iframe_element["data-post-author-id"]).to eq(author.id.to_s)

    # note: artifacts are within nested iframes for security reasons
    page.within_frame(iframe_element) do
      inner_iframe = find("iframe")
      page.within_frame(inner_iframe) do
        data_display_element = find("#data-display")

        expect(data_display_element.text).not_to be_empty
        expect(data_display_element.text).not_to eq("Waiting for data...")
        expect(data_display_element.text).not_to include("Error:")

        artifact_data_json = data_display_element.text
        artifact_data = JSON.parse(artifact_data_json)

        expect(artifact_data["customMessage"]).to eq("hello-from-post")
        expect(artifact_data["postAuthorId"]).to eq(author.id.to_s)

        expect(artifact_data["username"]).to eq(user.username)
      end
    end
  end
end
