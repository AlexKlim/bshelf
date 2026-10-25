require "rails_helper"

RSpec.describe User do
  it "deletes every owned row with the account" do
    book = create(:book, status: "done", finished_at: 1.day.ago)
    user = book.user
    create(:note, book:)
    create(:highlight, book:)
    user.source_connections.create!(kind: "litres")
    StatusResolver.manual!(book.readings.first, status: "in_progress")
    MergeEvent.create!(user:, book:)

    user.destroy!

    [ Book, Edition, Reading, StatusChange, Note, Highlight, SourceConnection, MergeEvent ].each do |model|
      expect(model.where(user_id: user.id)).to be_empty, "#{model} rows survived"
    end
  end
end
