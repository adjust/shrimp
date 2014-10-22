module Shrimp
  class PathValidator
    def initialize(path)
      @path = path
    end

    def is_in_conditions?(conditions)
      rules = [conditions].flatten
      is_in_rules?(rules)
    end

    def is_not_in_conditions?(conditions)
      !is_in_conditions?(conditions)
    end

    private

    def is_in_rules?(rules)
      rules.any? do |pattern|
        matches_pattern?(pattern)
      end
    end

    def matches_pattern?(pattern)
      if pattern.is_a?(Regexp)
        @path =~ pattern
      else
        @path[0, pattern.length] == pattern
      end
    end
  end
end
