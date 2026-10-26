require "rails_helper"

RSpec.describe Book do
  it "forgets the colour of the old cover unless the new one comes with it" do
    book = create(:book, cover_url: "https://www.litres.ru/a.jpg")
    book.update_columns(cloth: "oxblood", cloth_color: "#d30535")

    book.update!(cover_url: "https://www.litres.ru/b.jpg", cloth_color: "#23395b")
    expect(book.reload).to have_attributes(cloth_color: "#23395b", cloth: nil)

    book.update!(cover_url: "https://www.litres.ru/c.jpg")
    expect(book.reload).to have_attributes(cloth_color: nil, cloth: nil)
  end
end
