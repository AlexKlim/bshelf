require "rails_helper"

RSpec.describe LitresImport do
  let(:user) { create(:user) }

  def art(id, title, art_type: 1, persons: [ { "role" => "author", "full_name" => "Аркадий Стругацкий" } ])
    { "id" => id, "title" => title, "art_type" => art_type, "persons" => persons }
  end

  def edition(id) = user.editions.find_by(store: "litres", external_id: id.to_s)

  it "puts bought audiobooks and texts on the shelf as owned" do
    result = described_class.call(user, [ art(1, "Пикник на обочине"), art(2, "Солярис", art_type: 0, persons: []) ])

    expect(result).to eq(books: 2, highlights: 0)
    expect(edition(1)).to have_attributes(format: "audio", source: "litres")
    expect(edition(1).reading).to have_attributes(status: "owned", status_source: "litres")
    expect(edition(1).book.author).to eq("Аркадий Стругацкий")
    expect(edition(2).format).to eq("ebook")
  end

  it "does not add a book twice or override a status set by hand" do
    described_class.call(user, [ art(1, "Пикник на обочине") ])
    StatusResolver.manual!(edition(1).reading, status: "done")

    result = described_class.call(user, [ art(1, "Пикник на обочине") ])

    expect(result[:books]).to eq(0)
    expect(edition(1).reading.status).to eq("done")
  end

  it "takes the status from the Litres list the book came from" do
    described_class.call(user, [ art(1, "Пикник на обочине") ])

    described_class.call(user, [ art(1, "Пикник на обочине").merge("status" => "done"), art(2, "Солярис").merge("status" => "in_progress") ])

    expect(edition(1).reading).to have_attributes(status: "done", status_source: "litres")
    expect(edition(2).reading.status).to eq("in_progress")
  end

  it "skips entries without an id or a title" do
    expect(described_class.call(user, [ { "id" => 3 }, { "title" => "x" } ])[:books]).to eq(0)
  end
end
