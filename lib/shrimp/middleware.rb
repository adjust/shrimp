module Shrimp
  class Middleware
    def initialize(app, options = { }, conditions = { })
      @app                        = app
      @options                    = options
      @conditions                 = conditions
      @options[:polling_interval] ||= 1
      @options[:polling_offset]   ||= 1
      @options[:cache_ttl]        ||= 1
      @options[:request_timeout]  ||= @options[:polling_interval] * 10
    end

    def call(env)
      @request = Rack::Request.new(env)
      if render_as_pdf? #&& headers['Content-Type'] =~ /text\/html|application\/xhtml\+xml/
        if already_rendered? && (up_to_date?(@options[:cache_ttl]) || @options[:cache_ttl] == 0)
          if File.size(render_to) == 0
            File.delete(render_to)
            remove_rendering_flag
            return error_response
          end
          return ready_response if env['HTTP_X_REQUESTED_WITH']
          file = File.open(render_to, "rb")
          body = file.read
          file.close
          File.delete(render_to) if @options[:cache_ttl] == 0
          remove_rendering_flag
          response                  = [body]
          headers                   = { }
          headers["Content-Length"] = (body.respond_to?(:bytesize) ? body.bytesize : body.size).to_s
          headers["Content-Type"]   = "application/pdf"
          [200, headers, response]
        else
          if rendering_in_progress?
            if rendering_timed_out?
              remove_rendering_flag
              error_response
            else
              reload_response(@options[:polling_interval])
            end
          else
            File.delete(render_to) if already_rendered?
            set_rendering_flag
            fire_phantom
            reload_response(@options[:polling_offset])
          end
        end
      else
        @app.call(env)
      end
    end

    private

    # Private: start phantom rendering in a separate process
    def fire_phantom
      Process::detach fork { Phantom.new(@request.url.sub(%r{\.pdf$}, ''), @options, @request.cookies).to_pdf(render_to) }
    end

    def render_to
      file_name = Digest::MD5.hexdigest(@request.path) + ".pdf"
      file_path = @options[:out_path]
      "#{file_path}/#{file_name}"
    end

    def already_rendered?
      File.exists?(render_to)
    end

    def up_to_date?(ttl = 30)
      (Time.now - File.new(render_to).mtime) <= ttl
    end


    def remove_rendering_flag
      @request.session["phantom-rendering"] ||={ }
      @request.session["phantom-rendering"].delete(render_to)
    end

    def set_rendering_flag
      @request.session["phantom-rendering"]            ||={ }
      @request.session["phantom-rendering"][render_to] = Time.now
    end

    def rendering_timed_out?
      Time.now - @request.session["phantom-rendering"][render_to].to_time > @options[:request_timeout]
    end

    def rendering_in_progress?
      @request.session["phantom-rendering"]||={ }
      @request.session["phantom-rendering"][render_to]
    end

    def render_as_pdf?
      request_path_is_pdf = !!@request.path.match(%r{\.pdf$})

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

    def reload_response(interval=1)
      body = <<-HTML.gsub(/[ \n]+/, ' ').strip
          <html>
          <head>
        </head>
          <body onLoad="setTimeout(function(){ window.location.reload()}, #{interval * 1000});">
          <h2>Preparing pdf... </h2>
          </body>
        </ html>
      HTML
      headers                   = { }
      headers["Content-Length"] = body.size.to_s
      headers["Content-Type"]   = "text/html"
      headers["Retry-After"]    = interval.to_s

      [503, headers, [body]]
    end

    def ready_response
      body = <<-HTML.gsub(/[ \n]+/, ' ').strip
        <html>
        <head>
        </head>
        <body>
        <a href="#{@request.path}">PDF ready here</a>
        </body>
      </ html>
      HTML
      headers                   = { }
      headers["Content-Length"] = body.size.to_s
      headers["Content-Type"]   = "text/html"
      [200, headers, [body]]
    end

    def error_response
      body = <<-HTML.gsub(/[ \n]+/, ' ').strip
        <html>
        <head>
        </head>
        <body>
        <h2>Sorry request timed out... </h2>
        </body>
      </ html>
      HTML
      headers                   = { }
      headers["Content-Length"] = body.size.to_s
      headers["Content-Type"]   = "text/html"
      [504, headers, [body]]
    end
  end
end
