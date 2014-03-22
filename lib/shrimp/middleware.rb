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
      if render_as_pdf?
        if already_rendered? && (up_to_date?(@options[:cache_ttl]) || @options[:cache_ttl] == 0)
          if File.size(render_to) == 0
            File.delete(render_to)
            remove_rendering_flag
            return Response.error("PDF file invalid")
          end
          return Response.ready(@request.path) if env['HTTP_X_REQUESTED_WITH']
          file = File.open(render_to, "rb")
          body = file.read
          file.close
          File.delete(render_to) if @options[:cache_ttl] == 0
          remove_rendering_flag
          Response.file(body)
        else
          if rendering_in_progress?
            if rendering_timed_out?
              remove_rendering_flag
              Response.error("Rendering timeout")
            else
              Response.reload(@options[:polling_interval])
            end
          else
            File.delete(render_to) if already_rendered?
            set_rendering_flag
            fire_phantom
            Response.reload(@options[:polling_offset])
          end
        end
      else
        @app.call(env)
      end
    end

    private

    # Private: start phantom rendering in a separate process
    def fire_phantom
      Process::detach fork { Phantom.new(phantom_request_url, @options, @request.cookies).to_pdf(render_to) }
    end

    def phantom_request_url
      @request.url.sub(%r{\.pdf(\?.*)?$}, '\1')
    end

    def render_to
      file_path = @options[:out_path]
      "#{file_path}/#{render_file_name}"
    end

    def render_file_name
      Digest::MD5.hexdigest(@request.url) + ".pdf"
    end

    def already_rendered?
      File.exists?(render_to)
    end

    def up_to_date?(ttl = 30)
      (Time.now - File.new(render_to).mtime) <= ttl
    end

    def phantom_session
      @request.session["phantom-rendering"] ||= { }
    end

    def remove_rendering_flag
      phantom_session.delete(render_file_name)
    end

    def set_rendering_flag
      phantom_session[render_file_name] = Time.now
    end

    def rendering_timed_out?
      Time.now - phantom_session[render_file_name] > @options[:request_timeout]
    end

    def rendering_in_progress?
      phantom_session[render_file_name]
    end

    def render_as_pdf?
      return false unless request_path_is_pdf?

      if @conditions[:only]
        path_is_in_only_conditions?
      elsif @conditions[:except]
        path_is_not_in_except_conditions?
      else
        true
      end
    end

    def path_is_in_only_conditions?
      rules = [@conditions[:only]].flatten
      path_is_in_rules?(rules)
    end

    def path_is_not_in_except_conditions?
      rules = [@conditions[:except]].flatten
      !path_is_in_rules?(rules)
    end

    def path_is_in_rules?(rules)
      rules.any? do |pattern|
        path_matches_pattern?(pattern)
      end
    end

    def path_matches_pattern?(pattern)
      if pattern.is_a?(Regexp)
        @request.path =~ pattern
      else
        @request.path[0, pattern.length] == pattern
      end
    end

    def request_path_is_pdf?
      !!@request.path.match(%r{\.pdf$})
    end
  end
end
