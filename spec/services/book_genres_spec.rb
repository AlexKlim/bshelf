require "rails_helper"

RSpec.describe BookGenres do
  let(:user) { create(:user) }
  let(:client) { instance_double(JevClient) }

  it "asks Jev about books without a genre and remembers the answer for every reader" do
    book = create(:book, user:, title: "Гибкое сознание", author: "Кэрол Дуэк")
    create(:book, user:, title: "Solaris", author: "Stanisław Lem", genre: "fantasy")
    twin = create(:book, user: create(:user), title: "Гибкое сознание", author: "Кэрол Дуэк")
    allow(client).to receive(:genre).and_return("psychology")

    expect(described_class.call(user, client:)).to eq(1)
    described_class.call(twin.user, client:)

    expect(client).to have_received(:genre).once
    expect([ book.reload.genre, twin.reload.genre ]).to eq(%w[psychology psychology])
  end
end
