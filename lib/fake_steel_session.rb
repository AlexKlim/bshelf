# Stands in for Steel in development and test. Stateless across processes: the web process
# serves the viewer while a Solid Queue process creates and releases sessions.
class FakeSteelSession
  attr_reader :created, :released

  def initialize
    @created = []
    @released = []
  end

  def create_session
    SteelClient::Session.new(SecureRandom.uuid, "ws://steel.fake/devtools", "v1/sessions/debug").tap { @created << it.id }
  end

  def release(id) = @released << id

  def view(id, path, _query)
    html = "<!doctype html><title>Remote browser</title><p>Fake browser #{ERB::Util.h(id)} at /#{ERB::Util.h(path)}</p>"
    [ 200, "text/html; charset=utf-8", html ]
  end
end
