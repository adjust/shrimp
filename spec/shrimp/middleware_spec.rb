require 'spec_helper'

def app;
  Rack::Lint.new(@app)
end

def options
  { 
    format: 'Letter', 
    margin: '1cm', 
    tmpdir: Dir.tmpdir, 
    phantomjs: '/home/justin/Downloads/phantomjs-1.9.1-linux-x86_64/bin/phantomjs'
  }
end

def mock_app(options = { }, conditions = { })
  main_app = lambda { |env|
    headers = { 'Content-Type' => 'text/html' }
    [200, headers, ['Hello world!']]
  }

  @middleware = Shrimp::Middleware.new(main_app, options, conditions)
  @app        = Rack::Session::Cookie.new(@middleware, key: 'rack.session', secret: '53cr3t')
  #@middleware.should_receive(:fire_phantom).any_number_of_times
end


describe Shrimp::Middleware do
  before { mock_app(options) }

  context "matching pdf" do
    it "should render as pdf" do
      get '/test.pdf'
      @middleware.send(:'render_as_pdf?').should be true
    end

    it "should set render to to tmpdir" do
      get '/test.pdf'
      @middleware.send(:render_to).should match (Regexp.new("^#{options[:tmpdir]}"))
    end
  end

  context "not matching pdf" do
    it "should skip pdf rendering" do
      get '/test'
      last_response.body.should include "Hello world!"
      @middleware.send(:'render_as_pdf?').should be false
    end
  end
end

describe "Conditions" do
  context "only" do
    before { mock_app(options, :only => [%r[^/invoice], %r[^/public]]) }
    it "render pdf for set only option" do
      get '/invoice/test.pdf'
      @middleware.send(:'render_as_pdf?').should be true
    end

    it "render pdf for set only option" do
      get '/public/test.pdf'
      @middleware.send(:'render_as_pdf?').should be true
    end

    it "not render pdf for any other path" do
      get '/secret/test.pdf'
      @middleware.send(:'render_as_pdf?').should be false
    end
  end

  context "except" do
    before { mock_app(options, :except => %w(/secret)) }
    it "render pdf for set only option" do
      get '/invoice/test.pdf'
      @middleware.send(:'render_as_pdf?').should be true
    end

    it "render pdf for set only option" do
      get '/public/test.pdf'
      @middleware.send(:'render_as_pdf?').should be true
    end

    it "not render pdf for any other path" do
      get '/secret/test.pdf'
      @middleware.send(:'render_as_pdf?').should be false
    end
  end
end
