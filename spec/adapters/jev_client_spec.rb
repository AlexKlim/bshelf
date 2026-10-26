require "rails_helper"

RSpec.describe JevClient do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("OPENROUTER_API_KEY").and_return("test")
  end

  it "asks OpenRouter's decisions API whether two books are one and returns the probability" do
    request = stub_request(:post, "https://openrouter.ai/api/alpha/decisions")
      .with { |r| JSON.parse(r.body).then { it["model"] == "~typesafe/jev-latest" && it["state"].first.start_with?("Book A, a book: «Вдохновленные»") } }
      .to_return(status: 200, body: { answers: { same_book: { type: "noul", noul: 0.97 } } }.to_json)

    noul = described_class.new.same_book(build(:book, title: "Вдохновленные", author: "Марти Каган"), build(:book, title: "Inspired", author: "Marty Cagan"))

    expect(noul).to eq(0.97)
    expect(request).to have_been_made
  end
end
