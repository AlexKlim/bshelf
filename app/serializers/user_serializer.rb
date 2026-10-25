module UserSerializer
  def self.call(user) = { id: user.uuid, email: user.email, created_at: user.created_at }
end
