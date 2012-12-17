#encoding: UTF-8
require 'spec_helper'

describe Shrimp::Source do
  context "url" do
    it "should match file urls" do
      source = Shrimp::Source.new("file:///test/test.html")
      source.should be_url
    end
    it "should match http urls" do
      source = Shrimp::Source.new("http:///test/test.html")
      source.should be_url
    end
  end
end
