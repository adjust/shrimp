require "spec_helper"

describe Shrimp::PhantomRequest do

  let(:phantom_request) { Shrimp::PhantomRequest.new({}) }

  describe "#session_key" do
    it "returns a hash of the request URL" do
      phantom_request.should_receive(:url).and_return('/test/file.pdf')
      expect(phantom_request.session_key).to match(/\A[[:alnum:]]+\z/)
    end
  end

  describe "#phantom_request_url" do
    context "when the URL has no parameters" do
      it "removes the .pdf extension" do
        phantom_request.should_receive(:url).and_return('http://example.org/test.pdf')
        expect(phantom_request.phantom_request_url).to eq 'http://example.org/test'
      end
    end

    context "when the URL has parameters" do
      it "it preserves the parameters but removes the .pdf extension" do
        phantom_request.should_receive(:url).and_return('http://example.org/test.pdf?x=42')
        expect(phantom_request.phantom_request_url).to eq 'http://example.org/test?x=42'
      end
    end
  end

  describe "#path_is_pdf?" do
    it "returns true if the path has a .pdf extension" do
      phantom_request.should_receive(:path).and_return('/test/file.pdf')
      expect(phantom_request.path_is_pdf?).to eq true
    end

    it "returns false if the path has no .pdf extension" do
      phantom_request.should_receive(:path).and_return('/test/file.pdf.exe')
      expect(phantom_request.path_is_pdf?).to eq false
    end
  end

  describe "#set_rendering_flag" do
    it "set the rendering flag" do
      phantom_request.remove_rendering_flag
      phantom_request.set_rendering_flag

      key = phantom_request.session_key
      expect(phantom_request.send(:phantom_session)[key]).to_not be_nil
    end
  end

  describe "#remove_rendering_flag" do
    it "removes the rendering flag" do
      phantom_request.set_rendering_flag
      phantom_request.remove_rendering_flag

      key = phantom_request.session_key
      expect(phantom_request.send(:phantom_session)[key]).to be_nil
    end
  end

  describe "#rendering_in_progress?" do
    it "returns true when rendering is active" do
      phantom_request.remove_rendering_flag
      phantom_request.set_rendering_flag

      expect(phantom_request.rendering_in_progress?).to eq true
    end

    it "returns false when rendering is not active" do
      phantom_request.set_rendering_flag
      phantom_request.remove_rendering_flag

      expect(phantom_request.rendering_in_progress?).to eq false
    end
  end

  describe "#rendering_timeout?" do
    before do
      phantom_request.set_rendering_flag

      now = Time.now
      Time.should_receive(:now).and_return (now + 10)
    end

    it "returns true when rendering has timed out" do
      expect(phantom_request.rendering_timeout?(5)).to eq true
    end

    it "returns false when rendering is not timed out" do
      expect(phantom_request.rendering_timeout?(15)).to eq false
    end
  end

end
