require "rails_helper"

RSpec.describe FileTitle do
  it "turns a file name into words and leaves real titles alone" do
    expect(described_class.clean("Lensioni_Smert-ot-soveshchaniy.498941.fb2 (1)")).to eq("Lensioni Smert ot soveshchaniy")
    expect(described_class.clean("Atomic_Habits.epub")).to eq("Atomic Habits")
    expect(described_class.clean("Смерть от совещаний")).to eq("Смерть от совещаний")
    expect(described_class.clean("Sapiens: A Brief History (2)")).to eq("Sapiens: A Brief History (2)")
  end
  it "reads a numbered slug and an author with a series in brackets" do
    expect(described_class.parse("210777-lovtsyi-knig-volna-veroyatnosti")).to eq(title: "lovtsyi knig volna veroyatnosti", author: nil)
    expect(described_class.parse("Gibson Uilyam [Periferiynyie ustroystva#2] Periferiynyie ustroystva"))
      .to eq(title: "Periferiynyie ustroystva", author: "Gibson Uilyam")
  end

  it "drops the number in front of a slug when a document is imported" do
    expect(described_class.clean("51318-doch-dyima-i-kostey")).to eq("doch dyima i kostey")
    expect(described_class.clean("51318-doch-dyima-i-kostey.epub")).to eq("doch dyima i kostey")
  end

  it "leaves ordinary titles alone" do
    expect([ "Catch-22", "Project Hail Mary", "Война и мир", "Spider-Man", "X-Men-Gold" ].map { described_class.parse(it) }).to all(be_nil)
  end

  it "capitalizes a cleaned file name" do
    expect(described_class.readable("the martian")).to eq("The martian")
  end
end
