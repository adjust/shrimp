require 'spec_helper'

shared_context Shrimp::Middleware do
  def mock_app(options = { }, conditions = { })
    @middleware = Shrimp::Middleware.new(main_app, options, conditions)
    @app        = Rack::Session::Cookie.new(@middleware, :key => 'rack.session')
  end
end

describe Shrimp::Middleware do
  include_context Shrimp::Middleware

  before { mock_app(middleware_options) }
  subject { @middleware }

  context "matching pdf" do
    it "should render as pdf" do
      get '/test.pdf'
      @middleware.send(:render_as_pdf?).should be true
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

    it "should set render_to to out_path" do
      get '/test.pdf'
      @middleware.send(:render_to).should match (Regexp.new("^#{middleware_options[:out_path]}"))
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

    describe "when already_rendered? and up_to_date?" do
      before {
        mock_file = double(File, :read => "Hello World", :close => true, :mtime => Time.now)
        File.should_receive(:exists?).at_least(:once).and_return true
        File.should_receive(:size).and_return 1000
        File.should_receive(:open).and_return mock_file
        File.should_receive(:new).at_least(:once).and_return mock_file
        get '/test.pdf'
      }

      its(:rendering_in_progress?) { should eq false }
      its(:already_rendered?)      { should eq true }
      its(:up_to_date?)            { should eq true }

      it "should return a pdf with 200" do
        last_response.status.should eq 200
        last_response.headers['Content-Type'].should eq 'application/pdf'
        last_response.body.should eq "Hello World"
      end
    end

    describe "requesting a simple path" do
      before { get '/test.pdf' }
      its(:html_url) { should eq 'http://example.org/test' }
    end

    describe "requesting a path with a query string" do
      before { get '/test.pdf?size=10' }
      its(:html_url) { should eq 'http://example.org/test?size=10' }
    end
  end

  context "not matching pdf" do
    it "should skip pdf rendering" do
      get 'http://www.example.org/test'
      last_response.body.should include "Hello world!"
      @middleware.send(:render_as_pdf?).should be false
    end
  end
end

describe Shrimp::Middleware, "Conditions" do
  include_context Shrimp::Middleware

  context "only" do
    before { mock_app(middleware_options, :only => [%r[^/invoice], %r[^/public]]) }
    it "render pdf for set only option" do
      get '/invoice/test.pdf'
      @middleware.send(:render_as_pdf?).should be true
    end

    it "render pdf for set only option" do
      get '/public/test.pdf'
      @middleware.send(:render_as_pdf?).should be true
    end

    it "not render pdf for any other path" do
      get '/secret/test.pdf'
      @middleware.send(:render_as_pdf?).should be false
    end
  end

  context "except" do
    before { mock_app(middleware_options, :except => %w(/secret)) }
    it "render pdf for set only option" do
      get '/invoice/test.pdf'
      @middleware.send(:render_as_pdf?).should be true
    end

    it "render pdf for set only option" do
      get '/public/test.pdf'
      @middleware.send(:render_as_pdf?).should be true
    end

    it "not render pdf for any other path" do
      get '/secret/test.pdf'
      @middleware.send(:render_as_pdf?).should be false
    end
  end
end
