module McpTools
  def self.all = [ SearchShelf, ListShelf, GetBook, AddBook, RemoveBook, ReadingStats ]

  def self.allowed_for(scopes) = all.select { scopes.include?(it.required_scope) }
end
