require 'shrimp/path_validator'

module Shrimp
  class Conditions
    def initialize(conditions = {})
      @conditions = conditions
    end

    def path_is_valid?(path)
      validator = PathValidator.new(path)

      if @conditions[:only]
        validator.is_in_conditions?(@conditions[:only])
      elsif @conditions[:except]
        validator.is_not_in_conditions?(@conditions[:except])
      else
        true
      end
    end
  end
end
