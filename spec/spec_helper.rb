require 'URI'
require 'json'
require 'rack'
require 'rack/test'
require 'shrimp'


RSpec.configure do |config|
  include Rack::Test::Methods
end

