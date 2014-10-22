require 'shrimp/conditions'
require 'shrimp/phantom_request'

module Shrimp
  class Middleware
    def initialize(app, options = { }, conditions = { })
      @app                        = app
      @options                    = options
      @conditions                 = Conditions.new(conditions)
      @options[:polling_interval] ||= 1
      @options[:polling_offset]   ||= 1
      @options[:cache_ttl]        ||= 1
      @options[:request_timeout]  ||= @options[:polling_interval] * 10
    end

    def call(env)
      @request = PhantomRequest.new(env)

      if render_as_pdf?
        render_pdf
      else
        @app.call(env)
      end
    end

    private

    def render_pdf
      if pdf_ready?
        send_pdf
      elsif @request.rendering_in_progress?
        wait_for_rendering
      else
        start_rendering
      end
    end

    def pdf_ready?
      already_rendered? && (up_to_date?(@options[:cache_ttl]) || @options[:cache_ttl] == 0)
    end

    def send_pdf
      if File.zero?(render_to)
        File.delete(render_to)
        @request.remove_rendering_flag
        return Response.error("PDF file invalid")
      end

      return Response.ready(@request.path) if @request.xhr?

      body = read_pdf_contents
      File.delete(render_to) if @options[:cache_ttl] == 0
      @request.remove_rendering_flag
      Response.file(body)
    end

    def read_pdf_contents
      file = File.open(render_to, "rb")
      body = file.read
      file.close
      body
    end

    def wait_for_rendering
      if rendering_timed_out?
        @request.remove_rendering_flag
        Response.error("Rendering timeout")
      else
        Response.reload(@options[:polling_interval])
      end
    end

    def start_rendering
      File.delete(render_to) if already_rendered?
      @request.set_rendering_flag
      fire_phantom
      Response.reload(@options[:polling_offset])
    end

    # Private: start phantom rendering in a separate process
    def fire_phantom
      Process::detach fork { Phantom.new(@request.phantom_request_url, @options, @request.cookies).to_pdf(render_to) }
    end

    def render_to
      file_path = @options[:out_path]
      "#{file_path}/#{render_file_name}"
    end

    def render_file_name
      "#{@request.session_key}.pdf"
    end

    def already_rendered?
      File.exists?(render_to)
    end

    def up_to_date?(ttl = 30)
      (Time.now - File.new(render_to).mtime) <= ttl
    end

    def rendering_timed_out?
      @request.rendering_timeout? @options[:request_timeout]
    end

    def render_as_pdf?
      if @request.path_is_pdf?
        @conditions.path_is_valid? @request.path
      else
        false
      end
    end
  end
end
