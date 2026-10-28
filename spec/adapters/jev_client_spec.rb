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

  it "refuses an answer without a probability instead of reading it as no" do
    stub_request(:post, "https://openrouter.ai/api/alpha/decisions").to_return(status: 200, body: { answers: nil }.to_json)

    expect { described_class.new.same_book(build(:book), build(:book)) }.to raise_error(JevClient::Error)
  end

  it "asks which bookshop section a book belongs to and returns the chosen genre" do
    stub_request(:post, "https://openrouter.ai/api/alpha/decisions")
      .with { |r| JSON.parse(r.body).dig("questions", "genre", "criteria").keys == Book::GENRES.keys }
      .to_return(status: 200, body: { answers: { genre: { type: "choice", choice: "psychology", probabilities: { psychology: 0.9 } } } }.to_json)

    expect(described_class.new.genre(build(:book, title: "Гибкое сознание", author: "Кэрол Дуэк"))).to eq("psychology")
  end

  it "refuses a malformed genre answer" do
    stub_request(:post, "https://openrouter.ai/api/alpha/decisions")
      .to_return(status: 200, body: { answers: { genre: "psychology" } }.to_json)

    expect { described_class.new.genre(build(:book)) }.to raise_error(JevClient::Error)
  end

  it "refuses a genre outside the list" do
    stub_request(:post, "https://openrouter.ai/api/alpha/decisions")
      .to_return(status: 200, body: { answers: { genre: { type: "choice", choice: "poetry" } } }.to_json)

    expect { described_class.new.genre(build(:book)) }.to raise_error(JevClient::Error)
  end
end
