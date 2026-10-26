require "rails_helper"

RSpec.describe KindleImport do
  let(:user) { create(:user) }

  def item(asin, title, percent: 0, authors: [ "Strugatsky, Arkady:" ], origin: "PURCHASE")
    { "asin" => asin, "title" => title, "authors" => authors, "percentageRead" => percent, "originType" => origin }
  end

  def edition(asin) = user.editions.find_by(store: "amazon", external_id: asin)

  it "adds library books with a status from reading progress" do
    result = described_class.call(user, [ item("A1", "Roadside Picnic", percent: 100), item("A2", "Hard to Be a God", percent: 40),
      item("A3", "Monday Begins on Saturday"), item("A4", "Solaris", origin: "SAMPLE") ], {})

    expect(result).to eq(books: 4, highlights: 0)
    expect(%w[A1 A2 A3 A4].map { edition(it).reading.status }).to eq(%w[done in_progress owned want])
    expect(edition("A1")).to have_attributes(format: "ebook", source: "kindle_browser")
    expect(edition("A1").book.author).to eq("Arkady Strugatsky")
    expect(edition("A1").reading.status_source).to eq("kindle_browser")
  end

  it "moves an existing Kindle edition forward on the next sync without adding it again" do
    described_class.call(user, [ item("A1", "Roadside Picnic", percent: 10) ], {})

    result = described_class.call(user, [ item("A1", "Roadside Picnic", percent: 100) ], {})

    expect(result[:books]).to eq(0)
    expect(edition("A1").reading.status).to eq("done")
  end

  it "keeps a status the person set by hand" do
    described_class.call(user, [ item("A1", "Roadside Picnic", percent: 10) ], {})
    StatusResolver.manual!(edition("A1").reading, status: "want")

    described_class.call(user, [ item("A1", "Roadside Picnic", percent: 100) ], {})

    expect(edition("A1").reading.status).to eq("want")
  end

  it "adds the Kindle edition to a book already on the shelf" do
    book = AddBook.call(user:, title: "Roadside Picnic", author: "Arkady Strugatsky", format: "audio", store: "litres", external_id: "9")

    described_class.call(user, [ item("A1", "Roadside Picnic") ], {})

    expect(user.books.count).to eq(1)
    expect(book.editions.pluck(:store)).to contain_exactly("litres", "amazon")
  end

  it "replaces highlights of synced books and skips books it does not know" do
    described_class.call(user, [ item("A1", "Roadside Picnic") ], { "A1" => [ { "text" => "old" } ] })

    result = described_class.call(user, [], { "A1" => [ { "text" => "Happiness for everybody", "note" => "end", "location" => "42" } ],
      "ZZ" => [ { "text" => "unknown" } ] })

    expect(result[:highlights]).to eq(1)
    expect(user.highlights.pluck(:text, :note, :location, :source)).to eq([ [ "Happiness for everybody", "end", "42", "kindle_browser" ] ])
  end
end
