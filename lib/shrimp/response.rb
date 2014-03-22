module Shrimp
  class Response

    def self.file(contents)
      headers = {}
      headers["Content-Length"] = (contents.respond_to?(:bytesize) ? contents.bytesize : contents.size).to_s
      headers["Content-Type"] = "application/pdf"

      [200, headers, [contents]]
    end

    def self.ready(path)
      body = html_template("<a href=\"#{path}\">PDF ready here</a>")

      headers = html_headers(body)

      [200, headers, [body]]
    end

    def self.reload(interval=1)
      on_load = "setTimeout(function(){ window.location.reload()}, #{interval * 1000});"
      body = html_template("<h2>Preparing pdf... </h2>", on_load)

      headers = html_headers(body)
      headers["Retry-After"] = interval.to_s

      [503, headers, [body]]
    end

    def self.error(message)
      body = html_template("<h2>Sorry request timed out... #{message}</h2>")

      headers = html_headers(body)

      [504, headers, [body]]
    end

    private

    def self.html_template(content, on_load = '')
      <<-HTML.gsub(/[ \n]+/, ' ').strip
        <html>
        <head>
        </head>
        <body onLoad="#{on_load}">
        #{content}
        </body>
      </ html>
      HTML
    end

    def self.html_headers(body)
      {
        "Content-Length" => body.size.to_s,
        "Content-Type" => "text/html"
      }
    end
  end
end
