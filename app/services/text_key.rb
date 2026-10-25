# Comparison keys for titles and authors. No transliteration: Cyrillic and Latin never compare equal, so a
# Russian and an English edition meet only through original_title.
module TextKey
  def self.title(value)
    value.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase.gsub(/[^\p{L}\p{N}]+/, " ").strip
  end

  def self.core_title(value) = title(value.to_s.split(/[:.(\[]| - /).first)

  def self.titles(*values) = values.flat_map { [ title(it), core_title(it) ] }.reject(&:empty?).uniq

  def self.author_tokens(value) = title(value).split.reject { it.size < 2 }.to_set

  def self.script(value)
    if value.to_s.match?(/\p{Cyrillic}/) then :cyrillic
    elsif value.to_s.match?(/\p{Latin}/) then :latin
    end
  end

  # :same, :different, or :unknown when one side is blank or the scripts differ.
  def self.authors(a, b)
    left = author_tokens(a)
    right = author_tokens(b)
    return :unknown if left.empty? || right.empty? || script(a) != script(b)

    left.subset?(right) || right.subset?(left) ? :same : :different
  end
end
