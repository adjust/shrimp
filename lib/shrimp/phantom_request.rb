require 'digest/md5'

module Shrimp
  class PhantomRequest < Rack::Request

    def session_key
      Digest::MD5.hexdigest(url)
    end

    def path_is_pdf?
      !!path.match(%r{\.pdf$})
    end

    def phantom_request_url
      url.sub(%r{\.pdf(\?.*)?$}, '\1')
    end

    def remove_rendering_flag
      phantom_session.delete(session_key)
    end

    def set_rendering_flag
      phantom_session[session_key] = Time.now
    end

    def rendering_timeout?(timeout)
      Time.now - phantom_session[session_key] > timeout
    end

    def rendering_in_progress?
      !!phantom_session[session_key]
    end

    private

    def phantom_session
      session["phantom-rendering"] ||= {}
    end

  end
end
