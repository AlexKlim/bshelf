require "rails_helper"

RSpec.describe Book do
  it "drops stress marks but keeps й" do
    expect(create(:book, title: "Испыта\u0301ние", author: "Андрей Бе\u0301лый").title).to eq("Испытание")
    expect(described_class.new(title: "Тайный").title).to eq("Тайный")
  end

  it "forgets the colour of the old cover unless the new one comes with it" do
    book = create(:book, cover_url: "https://www.litres.ru/a.jpg")
    book.update_columns(cloth: "oxblood", cloth_color: "#d30535")

    book.update!(cover_url: "https://www.litres.ru/b.jpg", cloth_color: "#23395b")
    expect(book.reload).to have_attributes(cloth_color: "#23395b", cloth: nil)

    book.update!(cover_url: "https://www.litres.ru/c.jpg")
    expect(book.reload).to have_attributes(cloth_color: nil, cloth: nil)
  end
end
