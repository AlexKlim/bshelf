require "rails_helper"

RSpec.describe FileTitle do
  it "turns a file name into words and leaves real titles alone" do
    expect(described_class.clean("Lensioni_Smert-ot-soveshchaniy.498941.fb2 (1)")).to eq("Lensioni Smert ot soveshchaniy")
    expect(described_class.clean("Atomic_Habits.epub")).to eq("Atomic Habits")
    expect(described_class.clean("Смерть от совещаний")).to eq("Смерть от совещаний")
    expect(described_class.clean("Sapiens: A Brief History (2)")).to eq("Sapiens: A Brief History (2)")
  end
end
