module Shrimp
  class BaseMiddleware
    def initialize(app, options = { }, conditions = { })
      @app        = app
      @options    = Shrimp.config.to_h.merge(options)
      @conditions = conditions
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

    def call(env)
      if @options[:thread_safe]
        dup._call(env)
      else
        _call(env)
      end
    end

    def _call(env)
      @request = Rack::Request.new(env)
      if render_as_pdf?
        render_as_pdf(env)
      else
        @app.call(env)
      end
    end

    def render_to
      file_name = Digest::MD5.hexdigest(@request.path) + ".pdf"
      file_path = @options[:out_path]
      "#{file_path}/#{file_name}"
    end

    # The URL for the HTML-formatted web page that we are converting into a PDF.
    def html_url
      @request.url.sub(%r<\.pdf(\?|$)>, '\1')
    end

    private

    def render_pdf
      log_render_pdf_start
      Phantom.new(html_url, @options, @request.cookies).tap do |phantom|
        @phantom = phantom
        phantom.to_pdf(render_to)
        log_render_pdf_completion
      end
    end

    def log_render_pdf_start
      return unless @options[:debug]
      puts %(#{self.class}: Converting web page at #{(html_url).inspect} into a PDF ...)
    end

    def log_render_pdf_completion
      return unless @options[:debug]
      puts "#{self.class}: Finished converting web page at #{(html_url).inspect} into a PDF"
      if @phantom.error?
        puts "#{self.class}: Error: #{@phantom.error}"
      else
        puts "#{self.class}: Saved PDF to #{render_to}"
      end
    end

    def pdf_body
      file = File.open(render_to, "rb")
      body = file.read
      file.close
      body
    end

    def default_pdf_options
      {
        :type         => 'application/octet-stream'.freeze,
        :disposition  => 'attachment'.freeze,
      }
    end

    def pdf_headers(body, options = {})
      { }.tap do |headers|
        headers["Content-Length"] = (body.respond_to?(:bytesize) ? body.bytesize : body.size).to_s
        headers["Content-Type"]   = "application/pdf"

        # Based on send_file_headers! from actionpack/lib/action_controller/metal/data_streaming.rb
        options = default_pdf_options.merge(@options).merge(options)
        [:type, :disposition].each do |arg|
          raise ArgumentError, ":#{arg} option required" if options[arg].nil?
        end

        disposition = options[:disposition]
        disposition += %(; filename="#{options[:filename]}") if options[:filename]

        headers.merge!(
          'Content-Disposition'       => disposition,
          'Content-Transfer-Encoding' => 'binary'
        )
      end
    end

  end
end
