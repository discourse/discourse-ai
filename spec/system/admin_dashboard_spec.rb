# frozen_string_literal: true

RSpec.describe "Admin dashboard", type: :system do
  fab!(:admin)

  xit "displays the sentiment dashboard" do
    SiteSetting.ai_sentiment_enabled = true
    sign_in(admin)

    visit "/admin"
    find(".navigation-item.sentiment").click()

    expect(page).to have_css(".section.sentiment")
  end
end
