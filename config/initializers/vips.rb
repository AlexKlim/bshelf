# Covers are untrusted input: keep libvips to its fuzzed loaders. Without libvips installed, covers
# fail later in Cloth.from_image and books keep a hashed cloth.
begin
  require "vips"
  Vips.block_untrusted(true)
rescue LoadError
  nil
end
