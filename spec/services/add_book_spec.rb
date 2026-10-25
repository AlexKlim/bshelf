require "rails_helper"

RSpec.describe AddBook do
  context "with concurrent requests" do
    self.use_transactional_tests = false

    let!(:user) { create(:user) }

    after { user.destroy! }

    it "adds a title once when two requests race" do
      paused = Queue.new
      resume = Queue.new
      allow(described_class).to receive(:find_duplicate).and_wrap_original do |original, *args|
        original.call(*args).tap do
          next unless Thread.current[:pause]

          paused << true
          resume.pop
        end
      end

      first = Thread.new do
        Thread.current[:pause] = true
        described_class.call(user:, title: "Solaris")
      end
      paused.pop
      second = Thread.new do
        described_class.call(user:, title: "solaris ")
      rescue described_class::Duplicate => e
        e
      end
      wait_for_lock_waiter
      resume << true

      expect(second.value).to be_a(described_class::Duplicate).and have_attributes(book: first.value)
      expect(user.books.count).to eq(1)
    ensure
      resume << true
      [ first, second ].compact.each { it.join(5) }
    end
  end
end
