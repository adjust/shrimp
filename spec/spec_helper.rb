require 'rack/test'
require 'shrimp'

RSpec.configure do |config|
  include Rack::Test::Methods
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
