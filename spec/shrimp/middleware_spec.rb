require 'spec_helper'

def app;
  Rack::Lint.new(@app)
end

def options
  { :margin          => "1cm", :out_path => Dir.tmpdir,
    :polling_offset  => 10, :polling_interval => 1, :cache_ttl => 1,
    :request_timeout => 1 }
end

def mock_app(options = { }, conditions = { })
  main_app = lambda { |env|
    headers = { 'Content-Type' => "text/html" }
    [200, headers, ['Hello world!']]
  }

  @middleware = Shrimp::Middleware.new(main_app, options, conditions)
  @app        = Rack::Session::Cookie.new(@middleware, :key => 'rack.session', :secret => "secret")
end


describe Shrimp::Middleware do
  before { mock_app(options) }

  describe "rendering the PDF" do
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

    it "should return HTTP 200 after rendering as AJAX request" do
      mock_file = double(File, :read => "Hello World", :close => true, :mtime => Time.now)
      File.should_receive(:'exists?').and_return true
      File.should_receive(:'size').and_return 1000
      File.should_receive(:'new').and_return mock_file

      get '/test.pdf', nil, {'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest'}

      last_response.status.should eq 200
    end
  end

  describe "#render_to" do
    it "should be set to the outpath" do
      get '/test.pdf'
      @middleware.send(:render_to).should match (Regexp.new("^#{options[:out_path]}"))
    end

    it "should be the same path if the URLs are the same" do
      get '/test.pdf'
      first_render_to = @middleware.send(:render_to)
      get '/test.pdf'
      second_render_to = @middleware.send(:render_to)

      first_render_to.should eq second_render_to
    end

    it "should be a different path when the URL parameters differ" do
      get '/test.pdf'
      first_render_to = @middleware.send(:render_to)
      get '/test.pdf?x=42'
      second_render_to = @middleware.send(:render_to)

      first_render_to.should_not eq second_render_to
    end
  end

  describe "#render_as_pdf?" do
    context "without conditions" do
      context "the URL contains .pdf" do
        it "should render as pdf" do
          get '/test.pdf'
          @middleware.send(:'render_as_pdf?').should be true
        end
      end

      context "the URL contains .pdf and parameters" do
        it "should render as pdf" do
          get '/test.pdf?x=42'
          @middleware.send(:'render_as_pdf?').should be true
        end
      end

      context "the URL doesn't contain .pdf" do
        it "should skip pdf rendering" do
          get 'http://www.example.org/test'
          last_response.body.should include "Hello world!"
          @middleware.send(:'render_as_pdf?').should be false
        end
      end
    end

    context "with only condition" do
      before { mock_app(options, :only => [%r[^/invoice], %r[^/public]]) }

      context "when the url is in the only condition" do
        it "render pdf for set only option" do
          get '/invoice/test.pdf'
          @middleware.send(:'render_as_pdf?').should be true
        end

        it "render pdf for set only option" do
          get '/public/test.pdf'
          @middleware.send(:'render_as_pdf?').should be true
        end
      end

      context "when the url isn't in the only condition" do
        it "not render pdf for any other path" do
          get '/secret/test.pdf'
          @middleware.send(:'render_as_pdf?').should be false
        end
      end
    end

    context "with except condition" do
      before { mock_app(options, :except => %w(/secret)) }

      context "when the url isn't in the except condition" do
        it "render pdf for set only option" do
          get '/invoice/test.pdf'
          @middleware.send(:'render_as_pdf?').should be true
        end

        it "render pdf for set only option" do
          get '/public/test.pdf'
          @middleware.send(:'render_as_pdf?').should be true
        end
      end

      context "when the url is in the except condition" do
        it "not render pdf for any other path" do
          get '/secret/test.pdf'
          @middleware.send(:'render_as_pdf?').should be false
        end
      end
    end
  end

  describe "#phantom_request_url" do
    context "when the URL has no parameters" do
      it "removes the .pdf extension" do
        get 'http://example.org/test.pdf'
        @middleware.send(:phantom_request_url).should eq 'http://example.org/test'
      end
    end

    context "when the URL has parameters" do
      it "it preserves the parameters but removes the .pdf extension" do
        get 'http://example.org/test.pdf?x=42'
        @middleware.send(:phantom_request_url).should eq 'http://example.org/test?x=42'
      end
    end
  end
end
