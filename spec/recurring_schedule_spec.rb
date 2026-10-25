require "rails_helper"

RSpec.describe "config/recurring.yml" do
  it "defines valid production tasks" do
    schedule = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).fetch("production")
    tasks = schedule.map { |key, options| SolidQueue::RecurringTask.from_configuration(key, **options.symbolize_keys) }

    expect(tasks).to all(be_valid)
  end
end
