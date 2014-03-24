require 'spec_helper'

describe Shrimp::PathValidator do

  let(:validator) { Shrimp::PathValidator.new('/test/file.pdf') }

  describe "#is_in_conditions" do
    context "when conditions is an array of regular expression" do
      it "returns true when the path is in the conditions" do
        expect(validator.is_in_conditions?([%r[^/public], %r[^/test]])).to eq true
      end

      it "returns false when the path is not in the conditions" do
        expect(validator.is_in_conditions?([%r[^/public], %r[^/other]])).to eq false
      end
    end

    context "when conditions is an array of strings" do
      it "returns true when the path is in the conditions" do
        expect(validator.is_in_conditions?(%w{/public /test})).to eq true
      end

      it "returns false when the path is not in the conditions" do
        expect(validator.is_in_conditions?([%w{/public /other}])).to eq false
      end
    end

    context "when conditions is a single string" do
      it "returns true when the path is in the conditions" do
        expect(validator.is_in_conditions?('/test')).to eq true
      end

      it "returns false when the path is not in the conditions" do
        expect(validator.is_in_conditions?('/public')).to eq false
      end
    end
  end

  describe "#is_not_in_conditions" do
    context "when conditions is an array of regular expression" do
      it "returns false when the path is in the conditions" do
        expect(validator.is_not_in_conditions?([%r[^/public], %r[^/test]])).to eq false
      end

      it "returns true when the path is not in the conditions" do
        expect(validator.is_not_in_conditions?([%r[^/public], %r[^/other]])).to eq true
      end
    end

    context "when conditions is an array of strings" do
      it "returns false when the path is in the conditions" do
        expect(validator.is_not_in_conditions?(%w{/public /test})).to eq false
      end

      it "returns true when the path is not in the conditions" do
        expect(validator.is_not_in_conditions?([%w{/public /other}])).to eq true
      end
    end

    context "when conditions is a single string" do
      it "returns false when the path is in the conditions" do
        expect(validator.is_not_in_conditions?('/test')).to eq false
      end

      it "returns true when the path is not in the conditions" do
        expect(validator.is_not_in_conditions?('/public')).to eq true
      end
    end
  end
end
