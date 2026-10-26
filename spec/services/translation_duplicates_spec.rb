require "rails_helper"

RSpec.describe TranslationDuplicates do
  let(:user) { create(:user) }
  let(:client) { instance_double(JevClient) }

  it "asks Jev only about one author's books in two scripts and records the pairs it calls one book" do
    ru = create(:book, user:, title: "Вдохновленные", author: "Марти Каган")
    en = create(:book, user:, title: "Inspired", author: "Marty Cagan")
    other = create(:book, user:, title: "Empowered", author: "Marty Cagan")
    create(:book, user:, title: "Atomic Habits", author: "James Clear")
    allow(client).to receive(:same_book) { |a, b| [ a, b ].include?(en) ? 0.97 : 0.24 }

    expect(described_class.call(user, client:)).to eq(1)

    expect(client).to have_received(:same_book).twice
    expect(DuplicateCandidate.sole).to have_attributes(reason: "translation", book_id: [ ru, en ].map(&:id).min)
    expect(DuplicateCandidate.involving(other)).to be_empty
  end

  it "remembers Jev's answer and skips pairs already offered or dismissed" do
    create(:book, user:, title: "Смерть от совещаний", author: "Патрик Ленсиони")
    create(:book, user:, title: "Death by Meeting", author: "Patrick Lencioni")
    allow(client).to receive(:same_book).and_return(0.4)

    2.times { described_class.call(user, client:) }

    expect(client).to have_received(:same_book).once
  end
end
