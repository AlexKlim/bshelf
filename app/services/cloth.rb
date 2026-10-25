# Spine cloth rule from design/README.md «Корешки»: the nearest of eight cloths in OKLab, or a stable hash.
module Cloth
  NAMES = %w[oxblood bottle navy plum slate ochre sage linen].freeze
  SAMPLE = 24

  def self.oklab(r, g, b)
    lr, lg, lb = [ r, g, b ].map do |c|
      c /= 255.0
      c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
    end
    l = Math.cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
    m = Math.cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
    s = Math.cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
    [
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    ]
  end

  LABS = JSON.parse(Rails.root.join("design/tokens.json").read).dig("color", "tokens")
    .select { it["name"].in?(NAMES.map { |name| "spine-#{name}" }) }
    .to_h { [ it["name"].delete_prefix("spine-"), oklab(*it["value"].delete_prefix("#").scan(/../).map(&:hex)) ] }
    .freeze

  def self.nearest(r, g, b)
    lab = oklab(r, g, b)
    LABS.min_by { |_name, cloth| cloth.zip(lab).sum { |x, y| (x - y)**2 } }.first
  end

  def self.for_uuid(uuid) = NAMES[Zlib.crc32(uuid.to_s) % NAMES.size]

  # Covers come from catalog hosts, so only the formats they serve reach libvips' decoders.
  def self.image?(bytes)
    bytes.start_with?("\xFF\xD8\xFF".b, "\x89PNG\r\n\x1A\n".b, "GIF87a", "GIF89a") ||
      (bytes.start_with?("RIFF") && bytes.byteslice(8, 4) == "WEBP")
  end

  # Every pixel of a thumbnail votes for its nearest cloth, so a large flat background wins over a small
  # bright detail, which a plain average would smear into a muddy colour.
  def self.from_image(bytes)
    bytes = bytes.to_s.b
    return unless image?(bytes)

    require "vips"
    image = Vips::Image.thumbnail_buffer(bytes, SAMPLE).colourspace(:srgb)
    image = image.extract_band(0, n: 3) if image.bands > 3
    image.to_a.flatten(1).map { nearest(*it) }.tally.max_by(&:last).first
  rescue LoadError, NameError
    nil
  rescue Vips::Error
    nil
  end
end
