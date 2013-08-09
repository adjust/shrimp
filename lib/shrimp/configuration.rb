require 'tmpdir'

# Configure Phantomjs someplace sensible,
# like config/initializers/phantomjs.rb
#
# @example
#   Shrimp.configure do |config|
#     config.phantomjs = '/usr/local/bin/phantomjs'
#     config.format = 'Letter'
#   end
module Shrimp
  class Configuration
    attr_accessor :options

    [:format, :margin, :zoom, :orientation, :tmpdir, :phantomjs, 
     :rendering_time, :fail_silently].each do |m|
      define_method("#{m}=") do |val|
        @options[m]=val
      end
    end

    def initialize
      @options = {
          :format            => 'Letter',
          :margin            => '1cm',
          :zoom              => 1,
          :orientation       => 'portrait',
          :tmpdir            => Dir.tmpdir,
          :phantomjs         => Phantom.default_executable,
          :rendering_time    => 30000,
          :fail_silently     => false
      }
    end
  end

  class << self
    attr_accessor :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end
