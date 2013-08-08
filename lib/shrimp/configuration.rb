require 'tmpdir'
module Shrimp
  class Configuration
    attr_accessor :default_options
    attr_writer :phantomjs

    [:format, :margin, :zoom, :orientation, :tmpdir].each do |m|
      define_method("#{m}=") do |val|
        @default_options[m]=val
      end
    end

    def initialize
      @default_options = {
          :format            => 'Letter',
          :margin            => '1cm',
          :zoom              => 1,
          :orientation       => 'portrait',
          :tmpdir            => Dir.tmpdir
      }
    end

    def phantomjs
      @phantomjs ||= (defined?(Bundler::GemfileError) ? `bundle exec which phantomjs` : `which phantomjs`).chomp
    end
  end

  class << self
    attr_accessor :configuration
  end

  # Configure Phantomjs someplace sensible,
  # like config/initializers/phantomjs.rb
  #
  # @example
  #   Shrimp.configure do |config|
  #     config.phantomjs = '/usr/local/bin/phantomjs'
  #     config.format = 'Letter'
  #   end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end
