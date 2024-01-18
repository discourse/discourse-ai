# frozen_string_literal: true

RSpec.describe "Admin dashboard", type: :system do
  fab!(:admin)

  it "displays the sentiment dashboard" do
    sign_in(admin)
    visit "/admin"

    find(".navigation-item.sentiment").click()
    expect(page).to have_css(".section.sentiment")
  end
end
