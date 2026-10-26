class SteelTunnel
  FORWARDED = %w[Upgrade Connection Sec-WebSocket-Key Sec-WebSocket-Version Sec-WebSocket-Protocol Sec-WebSocket-Extensions].freeze

  def self.open(client, upstream, path:, host:, headers:, ttl:)
    lines = [ "GET #{path} HTTP/1.1", "Host: #{host}", *FORWARDED.filter_map { "#{it}: #{headers[it]}" if headers[it].present? } ]
    upstream.write("#{lines.join("\r\n")}\r\n\r\n")
    pipe(client, upstream, ttl:)
  end

  def self.pipe(client, upstream, ttl:)
    Thread.new do
      done = Queue.new
      [ [ client, upstream ], [ upstream, client ] ].each do |from, to|
        Thread.new do
          IO.copy_stream(from, to)
        rescue IOError, SystemCallError
          nil
        ensure
          done << true
        end
      end
      done.pop(timeout: ttl)
    ensure
      [ client, upstream ].each { it.close unless it.closed? }
    end
  end
end
