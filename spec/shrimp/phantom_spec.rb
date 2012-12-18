#encoding: UTF-8
require 'spec_helper'

def valid_pdf(io)
  case io
    when File
      io.read[0...4] == "%PDF"
    when String
      io[0...4] == "%PDF" || File.open(io).read[0...4] == "%PDF"
  end
end

def testfile
  File.expand_path('../test_file.html', __FILE__)
end

Shrimp.configure do |config|
  config.rendering_time = 1000
end

describe Shrimp::Phantom do
  before do
    Shrimp.configure do |config|
      config.rendering_time = 1000
    end
  end

  it "should initialize attributes" do
    phantom = Shrimp::Phantom.new("file://#{testfile}", { :margin => "2cm" }, { }, "#{Dir.tmpdir}/test.pdf")
    phantom.source.to_s.should eq "file://#{testfile}"
    phantom.options[:margin].should eq "2cm"
    phantom.outfile.should eq "#{Dir.tmpdir}/test.pdf"
  end

  it "should render a pdf file" do
    #phantom = Shrimp::Phantom.new("file://#{@path}")
    #phantom.to_pdf("#{Dir.tmpdir}/test.pdf").first should eq "#{Dir.tmpdir}/test.pdf"
  end

  it "should accept a local file url" do
    phantom = Shrimp::Phantom.new("file://#{testfile}")
    phantom.source.should be_url
  end

  it "should accept a URL as source" do
    phantom = Shrimp::Phantom.new("http://google.com")
    phantom.source.should be_url
  end

  it "should parse options into a cmd line" do
    phantom = Shrimp::Phantom.new("file://#{testfile}", { :margin => "2cm" }, { }, "#{Dir.tmpdir}/test.pdf")
    phantom.cmd.should include "test.pdf A4 1 2cm portrait"
    phantom.cmd.should include "file://#{testfile}"
    phantom.cmd.should include "lib/shrimp/rasterize.js"
  end

  context "rendering to a file" do
    before(:all) do
      phantom = Shrimp::Phantom.new("file://#{testfile}", { :margin => "2cm" }, { }, "#{Dir.tmpdir}/test.pdf")
      @result = phantom.to_file
    end

    it "should return a File" do
      @result.should be_a File
    end

    it "should be a valid pdf" do
      valid_pdf(@result)
    end
  end

  context "rendering to a pdf" do
    before(:all) do
      @phantom = Shrimp::Phantom.new("file://#{testfile}", { :margin => "2cm" }, { })
      @result  = @phantom.to_pdf("#{Dir.tmpdir}/test.pdf")
    end

    it "should return a path to pdf" do
      @result.should be_a String
      @result.should eq "#{Dir.tmpdir}/test.pdf"
    end

    it "should be a valid pdf" do
      valid_pdf(@result)
    end
  end

  context "rendering to a String" do
    before(:all) do
      phantom = Shrimp::Phantom.new("file://#{testfile}", { :margin => "2cm" }, { })
      @result = phantom.to_string("#{Dir.tmpdir}/test.pdf")
    end

    it "should return the File IO String" do
      @result.should be_a String
    end

    it "should be a valid pdf" do
      valid_pdf(@result)
    end
  end

  context "Error" do
    it "should return result nil" do
      phantom = Shrimp::Phantom.new("file://foo/bar")
      @result = phantom.run
      @result.should be_nil
    end

    it "should be unable to load the address" do
      phantom = Shrimp::Phantom.new("file:///foo/bar")
      phantom.run
      phantom.error.should include "Unable to load the address"
    end

    it "should be unable to copy file" do
      phantom = Shrimp::Phantom.new("file://#{testfile}")
      phantom.to_pdf("/foo/bar/")
      phantom.error.should include "Unable to copy file "
    end
  end

  context "Error Bang!" do

    it "should be unable to load the address" do
      phantom = Shrimp::Phantom.new("file:///foo/bar")
      expect { phantom.run! }.to raise_error Shrimp::RenderingError
    end

    it "should be unable to copy file" do
      phantom = Shrimp::Phantom.new("file://#{testfile}")
      expect { phantom.to_pdf!("/foo/bar/") }.to raise_error Shrimp::RenderingError
    end
  end
end
