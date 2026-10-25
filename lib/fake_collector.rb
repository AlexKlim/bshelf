# Collector for development and test: the person "signs in" a few seconds after the browser is
# live, then two steps finish. The real Kindle and Litres collectors replace it.
class FakeCollector
  attr_accessor :login_delay, :result

  def initialize(login_delay: 3.seconds, result: { books: 12, highlights: 40 })
    @login_delay = login_delay
    @result = result
  end

  def steps = %w[library highlights]

  def logged_in?(session) = session.expires_at - RemoteBrowserSession::LOGIN_TIME + login_delay <= Time.current

  def collect(_session)
    steps.each { yield it }
    result
  end
end
