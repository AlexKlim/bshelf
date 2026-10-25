{
  ru: {
    i18n: {
      plural: {
        rule: lambda do |n|
          if n % 10 == 1 && n % 100 != 11 then :one
          elsif (2..4).cover?(n % 10) && !(12..14).cover?(n % 100) then :few
          else :many
          end
        end
      }
    }
  }
}
