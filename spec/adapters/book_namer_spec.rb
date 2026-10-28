require "rails_helper"

RSpec.describe BookNamer do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("OPENROUTER_API_KEY").and_return("test")
  end

  def reply(content) = { choices: [ { message: { content: } } ] }.to_json

  it "asks a small model for the book's own spelling of a file name" do
    request = stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .with { |r| JSON.parse(r.body).then { it["model"] == "openai/gpt-5.4-mini" && it["messages"].last["content"].include?("doch dyima i kostey") } }
      .to_return(status: 200, body: reply({ title: "Дочь дыма и костей", author: nil }.to_json))

    expect(described_class.new.name("doch dyima i kostey", nil)).to eq("title" => "Дочь дыма и костей", "author" => nil)
    expect(request).to have_been_made
  end

  it "treats a null string as an unknown author" do
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .to_return(status: 200, body: reply({ title: "Наши друзья люди", author: "null" }.to_json))

    expect(described_class.new.name("Verber Bernar Nashi druzya lyudi", nil)).to eq("title" => "Наши друзья люди", "author" => nil)
  end

  it "joins several authors" do
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .to_return(status: 200, body: reply({ title: "Пикник на обочине", author: [ "Аркадий Стругацкий", " ", "Борис Стругацкий" ] }.to_json))

    expect(described_class.new.name("Piknik na obochine", nil)["author"]).to eq("Аркадий Стругацкий, Борис Стругацкий")
  end

  it "refuses an answer without a title" do
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions").to_return(status: 200, body: reply("not json"))

    expect { described_class.new.name("x", nil) }.to raise_error(BookNamer::Error)
  end
end
