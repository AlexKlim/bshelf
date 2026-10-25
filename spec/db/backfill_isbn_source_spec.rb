require "rails_helper"
require Rails.root.join("db/migrate/20261026100006_backfill_isbn_source.rb")

RSpec.describe BackfillIsbnSource do
  it "marks every stored ISBN as found by the catalog" do
    with_isbn = create(:book, isbn: "9780156027601")
    without_isbn = create(:book)

    ActiveRecord::Migration.suppress_messages { described_class.new.migrate(:up) }

    expect(with_isbn.reload.isbn_source).to eq("catalog")
    expect(without_isbn.reload.isbn_source).to be_nil
  end
end
