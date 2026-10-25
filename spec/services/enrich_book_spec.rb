require "rails_helper"

RSpec.describe EnrichBook do
  let(:cover) { "https://covers.openlibrary.org/b/id/12313764-L.jpg" }
  let(:archive) { "https://archive.org/download/l_covers_0012/l_covers_0012_31.zip/0012313764-L.jpg" }

  def stub_cover
    stub_request(:get, cover).to_return(status: 302, headers: { "Location" => archive })
    stub_request(:get, archive).to_return(status: 200, body: catalog_fixture("cover_solaris.jpg"))
  end

  it "fills blanks from Open Library and picks the cloth from the cover" do
    stub_open_library("open_library_solaris.json", title: "Solaris")
    stub_google("google_429.json", status: 429)
    stub_cover
    book = create(:book, title: "Solaris", author: "Stanisław Lem")

    described_class.call(book)

    expect(book.reload).to have_attributes(cover_url: cover, year: 1961, page_count: 229, language: nil,
      isbn: nil, cloth: "linen", match_source: "catalog", match_confidence: 0.9)
    expect(book.enriched_at).to be_present
  end

  it "falls back to Google Books for a Russian book Open Library does not know" do
    stub_open_library("open_library_solyaris.json")
    stub_google("google_solyaris.json")
    stub_request(:get, %r{\Ahttps://books\.google\.com/books/content}).to_return(status: 404)
    book = create(:book, title: "Солярис", author: "Станислав Лем")

    described_class.call(book)

    expect(book.reload).to have_attributes(language: "ru", page_count: 320, year: 2017, isbn: "9785171021906",
      cover_url: "https://books.google.com/books/content?id=q7JWDwAAQBAJ&printsec=frontcover&img=1&zoom=1&source=gbs_api",
      cloth: nil)
    expect(BookSerializer.summary(book, "want")[:cloth]).to eq(Cloth.for_uuid(book.uuid))
  end

  it "never overwrites known values and plants no ISBN on a title-only match" do
    stub_open_library("open_library_solaris.json")
    stub_google("google_429.json", status: 429)
    stub_cover
    book = create(:book, title: "Solaris", author: nil, year: 1972, language: "pl")

    described_class.call(book)

    expect(book.reload).to have_attributes(year: 1972, language: "pl", page_count: 229, isbn: nil, match_confidence: 0.6)
  end

  it "takes the original title from an ISBN hit" do
    stub_open_library("open_library_isbn.json", isbn: "9785171021906")
    stub_google("google_429.json", status: 429)
    stub_cover
    book = create(:book, title: "Солярис", author: "Станислав Лем", isbn: "9785171021906")

    described_class.call(book)

    expect(book.reload).to have_attributes(original_title: "Solaris", match_confidence: 1.0)
  end

  it "leaves the book for a retry when every provider that could have a cover is rate limited" do
    stub_open_library("open_library_solyaris.json")
    stub_google("google_429.json", status: 429, headers: { "Retry-After" => "120" })
    book = create(:book, title: "Солярис", author: "Станислав Лем")

    expect { described_class.call(book) }.to raise_error(CatalogClient::RateLimited) { expect(it.retry_after).to eq(120) }
    expect(book.reload.enriched_at).to be_nil
  end

  it "caches catalog answers across users, but not a 429" do
    stub_open_library("open_library_solaris.json")
    google = stub_google("google_429.json", status: 429)
    stub_cover

    2.times { described_class.call(create(:book, title: "Solaris", author: "Stanisław Lem")) }

    expect(a_request(:get, %r{openlibrary\.org/search})).to have_been_made.once
    expect(google).to have_been_made.twice
  end
end
