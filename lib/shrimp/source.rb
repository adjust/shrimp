require 'uri'
module Shrimp
  class Source
    def initialize(url_or_file)
      @source = url_or_file
      raise ImproperSourceError.new unless url? || file?
    end

    def url?
      @source.is_a?(String) && @source.match(URI::regexp)
    end

    def file?
      @source.kind_of?(File)
    end

    def html?
      !(url? || file?)
    end

    def to_s
      file? ? @source.path : @source
    end
  end
end
