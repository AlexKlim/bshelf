require "rails_helper"

RSpec.describe StatusResolver do
  let(:reading) { create(:reading, status: "in_progress", status_source: "kindle_export") }

  describe ".manual!" do
    it "always wins, can lower the status, and journals the change" do
      reading.update!(status: "done", status_source: "litres")

      expect(described_class.manual!(reading, status: "want", finished_at: nil)).to be(true)

      expect(reading).to have_attributes(status: "want", status_source: "manual", finished_at: nil)
      expect(reading.status_changes.last).to have_attributes(from_status: "done", to_status: "want", source: "manual")
    end

    it "keeps dates that were not passed" do
      reading.update!(started_at: Time.zone.parse("2025-03-01"))
      described_class.manual!(reading, status: "done", finished_at: Time.zone.parse("2025-04-01"))

      expect(reading.started_at).to eq(Time.zone.parse("2025-03-01"))
      expect(reading.finished_at).to eq(Time.zone.parse("2025-04-01"))
    end
  end

  describe ".automatic!" do
    it "never overwrites a manual status" do
      reading.update!(status: "in_progress", status_source: "manual")

      expect(described_class.automatic!(reading, status: "done", source: "litres")).to be(false)

      expect(reading).to have_attributes(status: "in_progress", status_source: "manual")
      expect(reading.status_changes).to be_empty
    end

    it "moves a manual want to owned on purchase" do
      reading.update!(status: "want", status_source: "manual")

      expect(described_class.automatic!(reading, status: "owned", source: "purchase")).to be(true)
      expect(reading).to have_attributes(status: "owned", status_source: "purchase")
    end

    it "moves a manual want to owned only on purchase" do
      reading.update!(status: "want", status_source: "manual")

      expect(described_class.automatic!(reading, status: "owned", source: "kindle_export")).to be(false)
      expect(reading).to have_attributes(status: "want", status_source: "manual")
    end

    it "does not let a manual want jump past owned" do
      reading.update!(status: "want", status_source: "manual")

      expect(described_class.automatic!(reading, status: "done", source: "kindle_export")).to be(false)
    end

    it "never lowers a status" do
      reading.update!(status: "done", status_source: "kindle_export")

      expect(described_class.automatic!(reading, status: "in_progress", source: "litres")).to be(false)
      expect(reading.status).to eq("done")
    end

    it "does not let a weaker source override a stronger one" do
      reading.update!(status: "in_progress", status_source: "litres")

      expect(described_class.automatic!(reading, status: "done", source: "kindle_export")).to be(false)
      expect(described_class.automatic!(reading, status: "done", source: "litres")).to be(true)
    end

    it "fills dates without erasing known ones" do
      reading.update!(started_at: Time.zone.parse("2025-01-01"))

      described_class.automatic!(reading, status: "done", source: "kindle_export",
        started_at: nil, finished_at: Time.zone.parse("2025-02-01"), total_minutes: 400)

      expect(reading).to have_attributes(started_at: Time.zone.parse("2025-01-01"),
        finished_at: Time.zone.parse("2025-02-01"), total_minutes: 400)
    end

    it "rejects manual as an automatic source" do
      expect { described_class.automatic!(reading, status: "done", source: "manual") }.to raise_error(ArgumentError)
    end
  end

  describe "job and manual edit racing" do
    it "keeps the manual status when a job writes a value it read before the edit" do
      job_decision = reading.status
      described_class.manual!(Reading.find(reading.id), status: "done")
      described_class.automatic!(reading, status: job_decision, source: "kindle_export")

      expect(reading.reload).to have_attributes(status: "done", status_source: "manual")
    end

    it "lets a manual edit win after a job write" do
      described_class.automatic!(reading, status: "done", source: "kindle_export")
      described_class.manual!(Reading.find(reading.id), status: "in_progress")

      expect(reading.reload).to have_attributes(status: "in_progress", status_source: "manual")
    end

    context "with real concurrent transactions" do
      self.use_transactional_tests = false

      let!(:reading) { create(:reading, status: "in_progress", status_source: "kindle_export") }

      after { reading.user.destroy! }

      it "blocks the job behind an uncommitted manual edit, then leaves it alone" do
        locked = Queue.new
        release = Queue.new
        manual = Thread.new do
          Reading.transaction do
            described_class.manual!(Reading.find(reading.id), status: "done")
            locked << true
            release.pop
          end
        end
        locked.pop
        job = Thread.new { described_class.automatic!(Reading.find(reading.id), status: "in_progress", source: "litres") }
        wait_for_lock_waiter
        expect(job).to be_alive
        release << true

        expect(job.value).to be(false)
        manual.join
        expect(reading.reload).to have_attributes(status: "done", status_source: "manual")
      end

      it "lets a manual edit that waits on a job's transaction win" do
        locked = Queue.new
        release = Queue.new
        job = Thread.new do
          Reading.transaction do
            described_class.automatic!(Reading.find(reading.id), status: "done", source: "litres")
            locked << true
            release.pop
          end
        end
        locked.pop
        manual = Thread.new { described_class.manual!(Reading.find(reading.id), status: "in_progress") }
        wait_for_lock_waiter
        expect(manual).to be_alive
        release << true

        expect(manual.value).to be(true)
        job.join
        expect(reading.reload).to have_attributes(status: "in_progress", status_source: "manual")
      end
    end
  end
end
