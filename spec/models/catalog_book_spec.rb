require "rails_helper"

RSpec.describe CatalogBook do
  def litres_book(user, id, cover_url: nil)
    book = create(:book, user:, title: "Спроси маму", author: "Роб Фитцпатрик", status: "owned", cover_url:)
    book.editions.first.update!(store: "litres", external_id: id)
    book.reload
  end

  it "fills a second reader's copy of a store book from the catalog without asking any outside service" do
    described_class.create!(title: "Спроси маму", author: "Роб Фитцпатрик", litres_id: "65834170", year: 2020, language: "ru",
      cover_url: "https://www.litres.ru/pub/c/cover/65834170.jpg", cloth: "oxblood", cloth_color: "#d30535")
    book = litres_book(create(:user), "65834170")

    EnrichBook.call(book)

    expect(book.reload).to have_attributes(year: 2020, language: "ru", cloth_color: "#d30535", cloth: "oxblood",
      cover_url: "https://www.litres.ru/pub/c/cover/65834170.jpg")
    expect(book.enriched_at).to be_present
  end

  it "keeps a reader's own cover and does not borrow the colour of another" do
    described_class.create!(title: "Спроси маму", author: "Роб Фитцпатрик", litres_id: "1", cover_url: "https://www.litres.ru/a.jpg",
      cloth: "oxblood", cloth_color: "#d30535", year: 2020)
    stub_request(:get, "https://www.litres.ru/b.jpg").to_return(status: 404)
    book = litres_book(create(:user), "1", cover_url: "https://www.litres.ru/b.jpg")

    EnrichBook.call(book)

    expect(book.reload).to have_attributes(cover_url: "https://www.litres.ru/b.jpg", cloth_color: nil, year: 2020)
  end

  it "learns a store book from its first reader" do
    stub_request(:get, %r{\Ahttps://openlibrary\.org/search\.json}).to_return(status: 200, body: { docs: [] }.to_json)
    stub_google("google_429.json", status: 429)
    book = litres_book(create(:user), "42")

    suppress(CatalogClient::RateLimited) { EnrichBook.call(book) }

    expect(described_class.find_by(litres_id: "42")).to have_attributes(title: "Спроси маму", author: "Роб Фитцпатрик")
  end

  it "never learns a book typed by hand that no catalog knows" do
    stub_request(:get, %r{\Ahttps://openlibrary\.org/search\.json}).to_return(status: 200, body: { docs: [] }.to_json)
    stub_google("google_429.json", status: 429)
    book = create(:book, title: "Моя тетрадка", author: "Я", status: "want")

    suppress(CatalogClient::RateLimited) { EnrichBook.call(book) }

    expect(described_class.count).to eq(0)
  end
end
