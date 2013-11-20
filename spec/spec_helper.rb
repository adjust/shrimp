require 'rack/test'
require 'shrimp'

RSpec.configure do |config|
  include Rack::Test::Methods
end

Shrimp.configure do |config|
  config.tmpdir = Dir.mktmpdir('shrimp')
end

def tmpdir
  Shrimp.configuration.default_options[:tmpdir]
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
