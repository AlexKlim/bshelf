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

  it "takes the cover from the library or from Manage your content" do
    owned = { "Ebook" => [ { "asin" => "A2", "title" => "Solaris", "productImage" => "https://m.media-amazon.com/images/I/2.jpg" } ] }
    described_class.call(user, [ item("A1", "Roadside Picnic").merge("productUrl" => "https://m.media-amazon.com/images/I/1.jpg") ], {}, owned)

    expect(edition("A1").book.cover_url).to eq("https://m.media-amazon.com/images/I/1.jpg")
    expect(edition("A2").book.cover_url).to eq("https://m.media-amazon.com/images/I/2.jpg")
  end

  it "decodes the HTML entities Amazon sends for Cyrillic titles and authors" do
    described_class.call(user, [ item("A9", "&#1050;&#1086;&#1084;&#1072;&#1085;&#1076;&#1072; &amp; &#1103;", authors: [ "&#1051;&#1077;&#1084;, &#1057;&#1090;&#1072;&#1085;&#1080;&#1089;&#1083;&#1072;&#1074;:" ]) ], {})

    expect(edition("A9").book).to have_attributes(title: "Команда & я", author: "Станислав Лем")
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

  describe "with the content page" do
    def owned(asin, title, read: false, origin: "Purchase", authors: [ "Tom DeMarco" ])
      { "asin" => asin, "title" => title, "readStatus" => read ? "READ" : "UNKNOWN", "originType" => origin,
        "bookProducerDetails" => authors.map { { "name" => it, "role" => "author" } } }
    end

    it "marks books Kindle calls READ as done and adds documents and audiobooks the library does not list" do
      result = described_class.call(user, [ item("A1", "Roadside Picnic", percent: 30) ], {},
        "Ebook" => [ owned("A1", "Roadside Picnic", read: true), owned("A2", "Slack", read: true),
          owned("D1", "Dictionary", origin: "KindleDictionary") ],
        "KindlePDoc" => [ owned("P1", "Пять искушений руководителя", authors: [ "Патрик Ленсиони" ]) ],
        "Audible" => [ owned("U1", "Project Hail Mary", authors: [ "Andy Weir" ]) ])

      expect(result[:books]).to eq(4)
      expect(edition("A1").reading.status).to eq("done")
      expect(edition("A2")).to have_attributes(format: "ebook")
      expect(edition("A2").reading.status).to eq("done")
      expect(edition("A2").book.author).to eq("Tom DeMarco")
      expect(edition("P1")).to have_attributes(format: "personal_doc")
      expect(edition("P1").reading.status).to eq("owned")
      expect(edition("U1")).to have_attributes(format: "audio")
      expect(edition("D1")).to be_nil
    end
  end
end
