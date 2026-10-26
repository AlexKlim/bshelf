class FakeSteelSession
  attr_reader :created, :released

  def initialize
    @created = []
    @released = []
  end

  def create_session(dimensions: nil)
    SteelClient::Session.new(SecureRandom.uuid, "ws://steel.fake/devtools", "v1/sessions/debug").tap { @created << it.id }
  end

  def release(id) = @released << id

  def ws_root = "ws://steel.fake/"

  def view(id, path, _query)
    html = "<!doctype html><title>Remote browser</title><p>Fake browser #{ERB::Util.h(id)} at /#{ERB::Util.h(path)}</p>"
    [ 200, "text/html; charset=utf-8", html ]
  end
end
