module Translit
  LETTERS = {
    "shch" => "щ", "sch" => "щ", "zh" => "ж", "kh" => "х", "ts" => "ц", "ch" => "ч", "sh" => "ш", "yu" => "ю",
    "ya" => "я", "yo" => "ё", "ye" => "е", "iy" => "ий", "yy" => "ый", "yi" => "ы",
    "a" => "а", "b" => "б", "v" => "в", "g" => "г", "d" => "д", "e" => "е", "z" => "з", "i" => "и", "j" => "й",
    "k" => "к", "l" => "л", "m" => "м", "n" => "н", "o" => "о", "p" => "п", "r" => "р", "s" => "с", "t" => "т",
    "u" => "у", "f" => "ф", "h" => "х", "c" => "к", "x" => "кс", "w" => "в", "q" => "к", "y" => "ы"
  }.freeze
  PATTERN = Regexp.union(LETTERS.keys.sort_by { -it.size })

  def self.to_cyrillic(text) = text.downcase.gsub(/(?<=[aeou])y(?![aeiouy])/, "й").gsub(PATTERN, LETTERS)

  def self.words(text) = text.downcase.tr("ёй", "еи").delete("ьъ").scan(/[\p{L}\d]+/)
end
