# Covers are untrusted input: keep libvips to its fuzzed loaders. Without libvips installed,
# Cloth.from_image returns nil, so enrichment still saves the catalog data and books keep a hashed cloth.
begin
  require "vips"
  Vips.block_untrusted(true)
rescue LoadError
  nil
end
