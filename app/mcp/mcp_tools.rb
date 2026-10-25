module McpTools
  def self.all = [ SearchShelf, GetBook, AddBook, ReadingStats ]

  def self.allowed_for(scopes) = all.select { scopes.include?(it.required_scope) }
end
