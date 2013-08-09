module Shrimp
  class Middleware
    def initialize(app, options = { }, conditions = { })
      @app                        = app
      @options                    = options
      @conditions                 = conditions
    end

    def call(env)
      @request = Rack::Request.new(env)
      if render_as_pdf? #&& headers['Content-Type'] =~ /text\/html|application\/xhtml\+xml/
        Phantom.new(Shrimp.configuration.options[:phantomjs], 
                    @request.url.sub(%r{\.pdf}, ''), @options, 
                    @request.cookies).to_pdf(render_to) 
        file = File.open(render_to, "rb")
        body = file.read
        file.close
        File.delete(render_to)
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

    def render_to
      file_name = Digest::MD5.hexdigest(@request.path) + ".pdf"
      file_path = Shrimp.configuration.options[:tmpdir]
      "#{file_path}/#{file_name}"
    end

    def render_as_pdf?
      request_path_is_pdf = !!@request.path.match(%r{\.pdf})

      if request_path_is_pdf && @conditions[:only]
        rules = [@conditions[:only]].flatten
        rules.any? do |pattern|
          if pattern.is_a?(Regexp)
            @request.path =~ pattern
          else
            @request.path[0, pattern.length] == pattern
          end
        end
      elsif request_path_is_pdf && @conditions[:except]
        rules = [@conditions[:except]].flatten
        rules.map do |pattern|
          if pattern.is_a?(Regexp)
            return false if @request.path =~ pattern
          else
            return false if @request.path[0, pattern.length] == pattern
          end
        end
        return true
      else
        request_path_is_pdf
      end
    end

    def concat(accepts, type)
      (accepts || '').split(',').unshift(type).compact.join(',')
    end

  end
end
