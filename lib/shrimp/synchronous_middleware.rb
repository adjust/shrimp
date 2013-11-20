require 'shrimp/base_middleware'

module Shrimp
  class SynchronousMiddleware < BaseMiddleware
    def render_as_pdf(env)
      # Start PhantomJS rendering in the same process (synchronously) and wait until it completes.
      render_pdf
      return phantomjs_error_response if phantom.error?

      body = pdf_body()
      headers = pdf_headers(body)
      [200, headers, [body]]
    end

    attr_reader :phantom

    private

    def phantomjs_error_response
      headers = {'Content-Type' => 'text/html'}
      if phantom.page_load_error?
        status_code = phantom.page_load_status_code
        headers['Location'] = phantom.redirect_to if phantom.redirect?
      else
        status_code = 500
      end
      [status_code, headers, [phantom.error]]
    end
  end
end
