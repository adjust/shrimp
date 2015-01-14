module Shrimp
  class StatelessMiddleware
    def initialize(app, options = { }, conditions = { })
      @app                        = app
      @options                    = options
      @conditions                 = conditions
    end

    def call(env)
      @request = Rack::Request.new(env)
      if render_as_pdf?
        body = Phantom.new(@request.url.sub(%r{\.pdf$}, ''), @options, @request.cookies).to_string
        response                  = [body]
        headers                   = { }
        headers["Content-Length"] = (body.respond_to?(:bytesize) ? body.bytesize : body.size).to_s
        headers["Content-Type"]   = "application/pdf"
        [200, headers, response]
      else
        @app.call(env)
      end
    end

    private

    def render_as_pdf?
      return false unless request_path_is_pdf
      return false if only_guard(:only, :path)
      return false if except_guard(:except, :path)
      return false if only_guard(:only_hosts, :host)
      return false if except_guard(:except_hosts, :host)
      true
    end

    def request_path_is_pdf
      !!@request.path.match(%r{\.pdf$})
    end

    def only_guard(guard, meth)
      @conditions[guard] && !guard(guard, meth)
    end

    def except_guard(guard, meth)
      @conditions[guard] && guard(guard, meth)
    end

    def guard(guard, meth)
      [@conditions[guard]].flatten.any? do |pattern|
        if pattern.is_a?(Regexp)
          @request.send(meth) =~ pattern
        else
          @request.send(meth).send(:[], 0, pattern.length) == pattern
        end
      end
    end
  end
end
