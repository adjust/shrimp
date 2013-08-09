require 'uri'
require 'json'
require 'digest'

module Shrimp
  class NoExecutableError < StandardError
    def initialize(phantom_location=nil)
      msg = "No phantomjs executable found at #{phantom_location}\n"
      msg << ">> Please install phantomjs - http://phantomjs.org/download.html"
      super(msg)
    end
  end

  class ImproperSourceError < StandardError
    def initialize(msg=nil)
      super("Improper Source: #{msg}")
    end
  end

  class RenderingError < StandardError
    def initialize(msg=nil)
      super("Rendering Error: #{msg}")
    end
  end

  class Phantom
    attr_accessor :source, :configuration, :outfile, :executable
    attr_reader :options, :cookies, :result, :error
    SCRIPT_FILE = File.expand_path('../rasterize.js', __FILE__)
    
    def self.default_executable
      (defined?(Bundler::GemfileError) ?  
       `bundle exec which phantomjs` : 
       `which phantomjs`).chomp
    end

    # Public: initializes a new Phantom Object
    #
    # url_or_file - The url of the html document to render
    # options     - a hash with options for rendering
    #   * format  - the paper format for the output eg: "5in*7.5in", 
    #               "10cm*20cm", "A4", "Letter"
    #   * zoom    - the viewport zoom factor
    #   * margin  - the margins for the pdf
    # cookies     - hash with cookies to use for rendering
    # outfile     - optional path for the output file. a Tempfile will be 
    #               created if not given
    #
    # Returns self
    def initialize(executable, url_or_file, options = {}, cookies={}, 
                   outfile = nil)
      @source  = Source.new(url_or_file)
      @options = Shrimp.configuration.options.merge(options)
      @cookies = cookies
      @outfile = outfile ? File.expand_path(outfile) : tmpfile
      @executable = executable || Phantom.default_executable
      raise NoExecutableError.new(@executable) unless File.exists?(@executable)
    end

    # Public: Runs the phantomjs binary
    #
    # Returns the stdout output of phantomjs
    def run
      @error  = nil
      @result = `#{cmd}`
      unless $?.exitstatus == 0
        @error  = @result
        @result = nil
        raise RenderingError.new(@error) unless options[:fail_silently]
      end
      @result
    end

    # Public: Returns the phantom rasterize command
    def cmd
      [@executable, SCRIPT_FILE, @source.to_s, @outfile, @options[:format], 
       @options[:zoom], @options[:margin], @options[:orientation], 
       dump_cookies, @options[:rendering_time]].join(" ")
    end

    # Public: renders to pdf
    # path  - the destination path defaults to outfile
    #
    # Returns the path to the pdf file
    def to_pdf(path=nil)
      @outfile = File.expand_path(path) if path
      self.run
      @outfile
    end

    # Public: renders to pdf
    # path  - the destination path defaults to outfile
    #
    # Returns a File Handle of the Resulting pdf
    def to_file(path=nil)
      self.to_pdf(path)
      File.new(@outfile)
    end

    # Public: renders to pdf
    # path  - the destination path defaults to outfile
    #
    # Returns the binary string of the pdf
    def to_string(path=nil)
      File.open(self.to_pdf(path)).read
    end

    private
    def tmpfile 
      "#{options[:tmpdir]}/#{Digest::MD5.hexdigest((
                             Time.now.to_i + rand(9001)).to_s)}.pdf"
    end

    def dump_cookies
      host = @source.url? ? URI::parse(@source.to_s).host : "/"
      json = @cookies.inject([]) { |a, (k, v)| 
               a.push({ :name => k, :value => v, :domain => host }); a 
             }.to_json
      File.open("#{options[:tmpdir]}/#{rand}.cookies", 'w') { |f| 
        f.puts json; f 
      }.path
    end
  end
end
