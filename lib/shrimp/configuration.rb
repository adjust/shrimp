require 'tmpdir'
module Shrimp
  class Configuration
    def initialize
      @options = {
        :format               => 'A4',
        :margin               => '1cm',
        :zoom                 => 1,
        :orientation          => 'portrait',
        :tmpdir               => Dir.mktmpdir('shrimp'),
        :rendering_timeout    => 90000,
        :rendering_time       => 1000,
        :command_config_file  => File.expand_path('../config.json', __FILE__),
        :viewport_width       => 600,
        :viewport_height      => 600,
        :debug                => false,
        :thread_safe          => true
      }
    end

    def to_h
      @options
    end

    [:format, :margin, :zoom, :orientation, :tmpdir, :rendering_timeout, :rendering_time, :command_config_file, :viewport_width, :viewport_height, :debug, :thread_safe].each do |m|
      define_method("#{m}=") do |val|
        @options[m] = val
      end

      define_method("#{m}") do
        @options[m]
      end
    end

    def phantomjs
      @phantomjs ||= (defined?(Bundler::GemfileError) ? `bundle exec which phantomjs` : `which phantomjs`).chomp
    end
    attr_writer :phantomjs
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end
    alias_method :config, :configuration

    def configure
      yield(configuration)
    end
  end

  # Configure Phantomjs someplace sensible,
  # like config/initializers/phantomjs.rb
  #
  # @example
  #   Shrimp.configure do |config|
  #     config.phantomjs = '/usr/local/bin/phantomjs'
  #     config.format = 'Letter'
  #   end

end
