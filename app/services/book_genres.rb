class BookGenres
  CHECKS = 200

  def self.call(user, client: JevClient.new)
    user.books.where(genre: nil).limit(CHECKS).count do |book|
      book.update!(genre: CatalogEntry.fetch(JevClient.genre_key(book)) { { "genre" => client.genre(book) } }["genre"])
    end
  end
end
