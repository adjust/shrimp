require "spec_helper"

describe Shrimp::Conditions do

  describe "#path_is_valid?" do
    context "with only conditions set" do
      let(:conditions) { Shrimp::Conditions.new({:only => "/test"}) }

      it "returns true when the path is in only conditions" do
        expect(conditions.path_is_valid?("/test/file.pdf")).to eq true
      end
    end

    context "with except conditions set" do
      let(:conditions) { Shrimp::Conditions.new({:except => "/test"}) }

      it "returns false when the path is in except conditions" do
        expect(conditions.path_is_valid?("/test/file.pdf")).to eq false
      end
    end

    context "with both only and except conditions set" do
      let(:conditions) { Shrimp::Conditions.new({:only => "/test", :except => "/test"}) }

      it "uses the only conditions" do
        expect(conditions.path_is_valid?("/test/file.pdf")).to eq true
      end
    end

    context "with no conditions set" do
      let(:conditions) { Shrimp::Conditions.new }

      it "returns true" do
        expect(conditions.path_is_valid?("/test/file.pdf")).to eq true
      end
    end
  end
end
