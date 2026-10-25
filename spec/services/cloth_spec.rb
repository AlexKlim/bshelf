require "rails_helper"
require "vips"

RSpec.describe Cloth do
  def solid_jpeg(r, g, b) = (Vips::Image.black(40, 60) + [ r, g, b ]).cast(:uchar).jpegsave_buffer

  it "maps each cloth token to itself" do
    tokens = JSON.parse(Rails.root.join("design/tokens.json").read).dig("color", "tokens").to_h { [ it["name"], it["value"] ] }

    described_class::NAMES.each do |name|
      rgb = tokens.fetch("spine-#{name}").delete_prefix("#").scan(/../).map(&:hex)
      expect(described_class.nearest(*rgb)).to eq(name)
    end
  end

  it "picks the nearest cloth by OKLab distance" do
    expect(described_class.nearest(200, 20, 30)).to eq("oxblood")
    expect(described_class.nearest(10, 20, 120)).to eq("navy")
    expect(described_class.nearest(250, 250, 245)).to eq("linen")
  end

  it "gives a cover the cloth most of its pixels are nearest to" do
    expect(described_class.from_image(solid_jpeg(30, 90, 70))).to eq("bottle")
    expect(described_class.from_image(catalog_fixture("cover_solaris.jpg"))).to eq("linen")
  end

  it "returns nil for bytes that are not an image" do
    expect(described_class.from_image("<html>")).to be_nil
  end

  it "hashes a uuid to a stable cloth" do
    uuid = SecureRandom.uuid

    expect(described_class.for_uuid(uuid)).to eq(described_class.for_uuid(uuid)).and be_in(described_class::NAMES)
    expect(Array.new(64) { described_class.for_uuid(SecureRandom.uuid) }.uniq.size).to be > 4
  end
end
