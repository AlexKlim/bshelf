module Cloth
  NAMES = %w[oxblood bottle navy plum slate ochre sage linen].freeze
  LIGHT_TEXT = %w[oxblood bottle navy plum slate].freeze
  SAMPLE = 24
  MIN_CONTRAST = 4.5

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

  def self.rgb(hex) = hex.delete_prefix("#").scan(/../).map(&:hex)

  TOKENS = JSON.parse(Rails.root.join("design/tokens.json").read).dig("color", "tokens").to_h { [ it["name"], it["value"] ] }.freeze
  LABS = NAMES.to_h { [ it, oklab(*rgb(TOKENS.fetch("spine-#{it}"))) ] }.freeze

  def self.luminance(r, g, b)
    lr, lg, lb = [ r, g, b ].map do |c|
      c /= 255.0
      c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
    end
    0.2126 * lr + 0.7152 * lg + 0.0722 * lb
  end

  def self.contrast(a, b) = ([ a, b ].max + 0.05) / ([ a, b ].min + 0.05)

  def self.readable(hex)
    text = %w[spine-text-light spine-text-dark].map { luminance(*rgb(TOKENS.fetch(it))) }
    color = rgb(hex)
    toward = contrast(luminance(*color), text[0]) >= contrast(luminance(*color), text[1]) ? 0 : 255
    best = text.max_by { contrast(luminance(*color), it) }
    color = color.map { it + ((toward - it) * 0.1).round } until contrast(luminance(*color), best) >= MIN_CONTRAST
    "#%02x%02x%02x" % color
  end

  def self.nearest(r, g, b)
    y = luminance(r, g, b)
    light = contrast(y, luminance(*rgb(TOKENS.fetch("spine-text-light")))) >= contrast(y, luminance(*rgb(TOKENS.fetch("spine-text-dark"))))
    lab = oklab(r, g, b)
    LABS.select { |name, _| LIGHT_TEXT.include?(name) == light }
      .min_by { |_name, cloth| (0.5 * (cloth[0] - lab[0]))**2 + (cloth[1] - lab[1])**2 + (cloth[2] - lab[2])**2 }.first
  end

  def self.for_uuid(uuid) = NAMES[Zlib.crc32(uuid.to_s) % NAMES.size]

  def self.image?(bytes)
    bytes.start_with?("\xFF\xD8\xFF".b, "\x89PNG\r\n\x1A\n".b, "GIF87a", "GIF89a") ||
      (bytes.start_with?("RIFF") && bytes.byteslice(8, 4) == "WEBP")
  end

  def self.from_image(bytes)
    bytes = bytes.to_s.b
    return unless image?(bytes)

    require "vips"
    return unless defined?(Vips::Image)

    image = Vips::Image.thumbnail_buffer(bytes, SAMPLE).colourspace(:srgb)
    image = image.extract_band(0, n: 3) if image.bands > 3
    pixels = image.to_a.flatten(1)
    common = pixels.group_by { |rgb| rgb.map { it >> 5 } }.values.max_by(&:size)
    readable("#%02x%02x%02x" % common.transpose.map { (it.sum / it.size.to_f).round })
  rescue LoadError
    nil
  rescue Vips::Error
    nil
  end
end
