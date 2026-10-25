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

  it "returns nil without libvips" do
    jpeg = solid_jpeg(30, 90, 70)
    allow(described_class).to receive(:require).with("vips").and_raise(LoadError, "libvips not found")

    expect(described_class.from_image(jpeg)).to be_nil

    allow(described_class).to receive(:require).with("vips").and_return(false)
    hide_const("Vips")

    expect(described_class.from_image(jpeg)).to be_nil
  end

  it "decodes only JPEG, PNG, WebP and GIF covers" do
    image = (Vips::Image.black(40, 60) + [ 30, 90, 70 ]).cast(:uchar)

    %i[pngsave_buffer webpsave_buffer gifsave_buffer].each do |save|
      expect(described_class.from_image(image.public_send(save))).to eq("bottle"), save.to_s
    end
    expect(described_class.from_image(image.tiffsave_buffer)).to be_nil
    expect(described_class.from_image(%(<svg xmlns="http://www.w3.org/2000/svg"><rect fill="#1e5a46" width="9" height="9"/></svg>)))
      .to be_nil
  end

  it "hashes a uuid to a stable cloth" do
    uuid = SecureRandom.uuid

    expect(described_class.for_uuid(uuid)).to eq(described_class.for_uuid(uuid)).and be_in(described_class::NAMES)
    expect(Array.new(64) { described_class.for_uuid(SecureRandom.uuid) }.uniq.size).to be > 4
  end
end
