require "rails_helper"

RSpec.describe Edition do
  it "allows one edition per store external id per user" do
    book = create(:book)
    create(:edition, book:, store: "amazon", external_id: "B00ASIN")

    expect { create(:edition, book:, store: "amazon", external_id: "B00ASIN") }
      .to raise_error(ActiveRecord::RecordNotUnique)
    expect { create(:edition, book:, store: "litres", external_id: "B00ASIN") }.not_to raise_error
    expect { create(:edition, book: create(:book), store: "amazon", external_id: "B00ASIN") }.not_to raise_error
  end

  it "allows many manual editions without an external id" do
    book = create(:book)
    expect { 2.times { create(:edition, book:) } }.not_to raise_error
  end
end
