module FileTitle
  EXTENSIONS = /(\.(fb2|epub|pdf|mobi|azw3?|docx?|txt|rtf|djvu))+(\.zip)?\z/i
  SERIES = /\A(?<author>[^\[\]]+?)\s*\[[^\]]*#\d+\]\s*(?<title>.+)\z/
  SLUG = /\A(?:\d+[-_][\p{Latin}\d]+(?:[-_][\p{Latin}\d]+)+|[a-z\d]+(?:[-_][a-z\d]+){2,})\z/

  def self.clean(title)
    name = title.sub(/\s*\(\d+\)\z/, "")
    bare = name.sub(EXTENSIONS, "").sub(/\.\d+\z/, "")
    return parse(bare)[:title] if bare.match?(SLUG)
    return title unless name.match?(EXTENSIONS) || (name.include?("_") && !name.include?(" "))

    bare.tr("_", " ").gsub(/(?<=\p{L})-(?=\p{L})/, " ").squish.presence || title
  end

  def self.parse(title)
    if (m = title.match(SERIES))
      { title: m[:title].strip, author: m[:author].strip }
    elsif title.match?(SLUG)
      { title: title.sub(/\A\d+[-_]/, "").tr("-_", "  ").squeeze(" "), author: nil }
    end
  end

  def self.readable(text) = text.sub(/\p{L}/, &:upcase)
end
