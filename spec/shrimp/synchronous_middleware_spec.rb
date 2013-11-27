require 'spec_helper'

shared_context Shrimp::SynchronousMiddleware do
  def mock_app(options = { }, conditions = { })
    @middleware = Shrimp::SynchronousMiddleware.new(main_app, options, conditions)
    @app        = Rack::Session::Cookie.new(@middleware, :key => 'rack.session')
  end
end

describe Shrimp::SynchronousMiddleware do
  include_context Shrimp::SynchronousMiddleware

  before { mock_app(middleware_options) }
  subject { @middleware }

  context "matching pdf" do
    describe "requesting a simple path" do
      before { get '/test.pdf' }
      its(:html_url) { should eq 'http://example.org/test' }
      its(:render_as_pdf?) { should be true }
      it { @middleware.send(:render_to).should start_with middleware_options[:out_path] }
      it "should return a 404 status because http://example.org/test does not exist" do
        last_response.status.should eq 404
        last_response.body.       should eq "404 Unable to load the address!"
        @middleware.phantom.error.should eq "404 Unable to load the address!"
      end
    end

    describe "requesting a path with a query string" do
      before { get '/test.pdf?size=10' }
      its(:render_as_pdf?) { should be true }
      its(:html_url) { should eq 'http://example.org/test?size=10' }
    end

    describe "requesting a simple path (and we stub html_url to a file url)" do
      before { @middleware.stub(:html_url).and_return "file://#{test_file}" }
      before { get '/test.pdf' }
      it "should return a valid pdf with 200 status" do
        last_response.status.should eq 200
        last_response.headers['Content-Type'].should eq 'application/pdf'
        valid_pdf?(last_response.body).should eq true
        @middleware.phantom.result.should start_with "rendered to: #{@middleware.render_to}"
      end
    end

    context 'requesting an HTML resource that sets a X-Pdf-Filename header' do
      before {
        @middleware.stub(:html_url).and_return "file://#{test_file}"
        phantom = Shrimp::Phantom.new(@middleware.html_url)
        phantom.stub :response_headers => {
          'X-Pdf-Filename' => 'Some Fancy Report Title.pdf'
        }
        Shrimp::Phantom.should_receive(:new).and_return phantom
      }
      before { get '/use_different_filename.pdf' }
      it "should use the filename from the X-Pdf-Filename header" do
        last_response.status.should eq 200
        last_response.headers['Content-Type'].should eq 'application/pdf'
        last_response.headers['Content-Disposition'].should eq %(attachment; filename="Some Fancy Report Title.pdf")
        valid_pdf?(last_response.body).should eq true
      end
    end

    context 'requesting an HTML resource that redirects' do
      before {
        phantom = Shrimp::Phantom.new('http://example.org/redirect_me')
        phantom.should_receive(:to_pdf).and_return nil
        phantom.stub :error => "302 Unable to load the address!",
                     :redirect_to => "http://localhost:8800/sign_in"
        Shrimp::Phantom.should_receive(:new).and_return phantom
      }
      before { get '/redirect_me.pdf' }
      it "should follow the redirect that the phantomjs request encountered" do
        # This tests the phantomjs_error_response method
        last_response.status.should eq 302
        last_response.headers['Content-Type'].should eq 'text/html'
        last_response.headers['Location'].should eq "http://#{local_server_host}/sign_in"
        @middleware.phantom.error. should eq "302 Unable to load the address!"
      end
    end
  end

  context "not matching pdf" do
    it "should skip pdf rendering" do
      get 'http://www.example.org/test'
      last_response.body.should include "Hello world!"
      @middleware.render_as_pdf?.should be false
    end
  end
end

describe Shrimp::SynchronousMiddleware, "Conditions" do
  include_context Shrimp::SynchronousMiddleware

  context "only" do
    before { mock_app(middleware_options, :only => [%r[^/invoice], %r[^/public]]) }
    it "render pdf for set only option" do
      get '/invoice/test.pdf'
      @middleware.render_as_pdf?.should be true
    end

    it "render pdf for set only option" do
      get '/public/test.pdf'
      @middleware.render_as_pdf?.should be true
    end

    it "not render pdf for any other path" do
      get '/secret/test.pdf'
      @middleware.render_as_pdf?.should be false
    end
  end

  context "except" do
    before { mock_app(middleware_options, :except => %w(/secret)) }
    it "render pdf for set only option" do
      get '/invoice/test.pdf'
      @middleware.render_as_pdf?.should be true
    end

    it "render pdf for set only option" do
      get '/public/test.pdf'
      @middleware.render_as_pdf?.should be true
    end

    it "not render pdf for any other path" do
      get '/secret/test.pdf'
      @middleware.render_as_pdf?.should be false
    end
  end
end
