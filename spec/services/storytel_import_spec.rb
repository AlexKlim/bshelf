require "rails_helper"

RSpec.describe StorytelImport do
  let(:user) { create(:user) }

  def item(id, title, state: "WILL_CONSUME", formats: [ { "type" => "abook", "cover" => { "url" => "https://covers.storytel.com/#{id}.jpg" } } ],
    authors: [ { "id" => "1", "name" => "Аркадий Стругацкий" }, { "id" => "2", "name" => "Борис Стругацкий" } ], action: "UPSERT")
    { "action" => action, "model" => { "id" => id, "title" => title, "state" => state, "formats" => formats, "authors" => authors } }
  end

  def edition(id) = user.editions.find_by(store: "storytel", external_id: id)

  it "puts the bookshelf on the shelf with its listening state, authors and cover" do
    result = described_class.call(user, [ item("1", "Пикник на обочине", state: "CONSUMED"), item("2", "Солярис", formats: [ { "type" => "ebook" } ], authors: []),
      item("3", "Улитка на склоне", state: "CONSUMING") ])

    expect(result).to eq(books: 3, highlights: 0)
    expect(edition("1")).to have_attributes(format: "audio", source: "storytel")
    expect(edition("1").reading).to have_attributes(status: "done", status_source: "storytel")
    expect(edition("1").book).to have_attributes(author: "Аркадий Стругацкий, Борис Стругацкий", cover_url: "https://covers.storytel.com/1.jpg")
    expect(edition("2")).to have_attributes(format: "ebook")
    expect(edition("2").reading.status).to eq("want")
    expect(edition("3").reading.status).to eq("in_progress")
  end

  it "moves a status forward on the next sync but never back or over a manual one" do
    described_class.call(user, [ item("1", "Пикник на обочине", state: "CONSUMING"), item("2", "Солярис") ])
    StatusResolver.manual!(edition("2").reading, status: "done")

    expect(described_class.call(user, [ item("1", "Пикник на обочине", state: "CONSUMED"), item("2", "Солярис", state: "CONSUMING") ])[:books]).to eq(0)
    expect(edition("1").reading.status).to eq("done")
    expect(edition("2").reading.status).to eq("done")
  end

  it "skips removed items, broken items and books the person threw away" do
    described_class.call(user, [ item("1", "Пикник на обочине") ])
    edition("1").book.discard!

    result = described_class.call(user, [ item("1", "Пикник на обочине"), item("2", "Солярис", action: "REMOVE"), { "model" => { "id" => "3" } }, {} ])

    expect(result[:books]).to eq(0)
    expect(edition("2")).to be_nil
  end
end
