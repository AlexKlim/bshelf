module FileTitle
  EXTENSIONS = /(\.(fb2|epub|pdf|mobi|azw3?|docx?|txt|rtf|djvu))+(\.zip)?\z/i

  def self.clean(title)
    name = title.sub(/\s*\(\d+\)\z/, "")
    return title unless name.match?(EXTENSIONS) || (name.include?("_") && !name.include?(" "))

    name = name.sub(EXTENSIONS, "").sub(/\.\d+\z/, "")
    name.tr("_", " ").gsub(/(?<=\p{L})-(?=\p{L})/, " ").squish.presence || title
  end
end
