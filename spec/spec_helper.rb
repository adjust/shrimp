require 'rack/test'
require 'shrimp'
require 'webrick'

RSpec.configure do |config|
  include Rack::Test::Methods
end

Shrimp.configure do |config|
end

def tmpdir
  Shrimp.config.tmpdir
end

def test_file
  File.expand_path('../shrimp/test_file.html', __FILE__)
end

def valid_pdf?(io)
  case io
    when File
      io.read[0...4] == "%PDF"
    when String
      io[0...4] == "%PDF" || File.open(io).read[0...4] == "%PDF"
  end
end

# Used by rack-test when we call get
def app
  Rack::Lint.new(@app)
end

def main_app
  lambda { |env|
    headers = { 'Content-Type' => "text/html" }
    [200, headers, ['Hello world!']]
  }
end

def middleware_options
  {
    :margin         => "1cm",
    :out_path         => tmpdir,
    :polling_offset   => 10,
    :polling_interval => 1,
    :cache_ttl        => 3600,
    :request_timeout  => 1
  }
end

def local_server_port
  8800
end
def local_server_host
  "localhost:#{local_server_port}"
end

def with_local_server
  webrick_options = {
    :Port   => local_server_port,
    :AccessLog => [],
    :Logger => WEBrick::Log::new(RUBY_PLATFORM =~ /mswin|mingw/ ? 'NUL:' : '/dev/null', 7)
  }
  begin
    # The "TCPServer Error: Address already in use - bind(2)" warning here appears to be bogus,
    # because it occurs even the first time we start the server and nothing else is bound to the
    # port.
    server = WEBrick::HTTPServer.new(webrick_options)
    trap("INT") { server.shutdown }
    Thread.new { server.start }
    yield server
    server.shutdown
  ensure
    server.shutdown if server
  end
end
