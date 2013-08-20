require 'spec_helper'

def app;
  Rack::Lint.new(@app)
end

def options
  { :margin          => "1cm", :out_path => Dir.tmpdir,
    :polling_offset  => 10, :polling_interval => 1, :cache_ttl => 3600,
    :request_timeout => 1 }
end

def mock_app(options = { }, conditions = { })
  main_app = lambda { |env|
    headers = { 'Content-Type' => "text/html" }
    [200, headers, ['Hello world!']]
  }

  @middleware = Shrimp::Middleware.new(main_app, options, conditions)
  @app        = Rack::Session::Cookie.new(@middleware, :key => 'rack.session')
end


describe Shrimp::Middleware do
  before { mock_app(options) }

  context "matching pdf" do
    it "should render as pdf" do
      get '/test.pdf'
      @middleware.send(:'render_as_pdf?').should be true
    end
    it "should return 503 the first time" do
      get '/test.pdf'
      last_response.status.should eq 503
      last_response.header["Retry-After"].should eq "10"
    end

    it "should return 503 the with polling interval the second time" do
      get '/test.pdf'
      get '/test.pdf'
      last_response.status.should eq 503
      last_response.header["Retry-After"].should eq "1"
    end

    it "should set render to to outpath" do
      get '/test.pdf'
      @middleware.send(:render_to).should match (Regexp.new("^#{options[:out_path]}"))
    end

    it "should return 504 on timeout" do
      get '/test.pdf'
      sleep 1
      get '/test.pdf'
      last_response.status.should eq 504
    end

    it "should retry rendering after timeout" do
      get '/test.pdf'
      sleep 1
      get '/test.pdf'
      get '/test.pdf'
      last_response.status.should eq 503
    end

    it "should return a pdf with 200 after rendering" do
      mock_file = double(File, :read => "Hello World", :close => true, :mtime => Time.now)
      File.should_receive(:'exists?').and_return true
      File.should_receive(:'size').and_return 1000
      File.should_receive(:'open').and_return mock_file
      File.should_receive(:'new').and_return mock_file
      get '/test.pdf'
      last_response.status.should eq 200
      last_response.body.should eq "Hello World"
    end


  end
  context "not matching pdf" do
    it "should skip pdf rendering" do
      get 'http://www.example.org/test'
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
