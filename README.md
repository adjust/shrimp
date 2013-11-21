# Shrimp
[![Build Status](https://travis-ci.org/adeven/shrimp.png?branch=master)](https://travis-ci.org/adeven/shrimp)
Creates PDFs from web pages using PhantomJS

Read our [blog post](http://big-elephants.com/2012-12/pdf-rendering-with-phantomjs/) about how it works.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'shrimp'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install shrimp

### PhantomJS

See http://phantomjs.org/download.html for instructions on how to install PhantomJS.

## Usage

```ruby
require 'shrimp'
url     = 'http://www.google.com'
options = { :margin => "1cm"}
Shrimp::Phantom.new(url, options).to_pdf("~/output.pdf")
```
## Configuration

Here is a list of configuration options that you can set.  Unless otherwise noted in comments, the
value shown is the default value.

Many of these options correspond to a property of the [WebPage module]
(https://github.com/ariya/phantomjs/wiki/API-Reference-WebPage) in PhantomJS.  Refer to that
[documentation](https://github.com/ariya/phantomjs/wiki/API-Reference-WebPage) for more information
about what those options do.

```ruby
Shrimp.configure do |config|

  # The path to the phantomjs executable.  Defaults to the path returned by `which phantomjs`.
  config.phantomjs = '/usr/local/bin/phantomjs'

  # The paper size/format to use for the generated PDF file. Examples: "5in*7.5in", "10cm*20cm",
  # "A4", "Letter". (See https://github.com/ariya/phantomjs/wiki/API-Reference-WebPage#papersize-object
  # for a list of valid options.)
  config.format = 'A4'

  # The page margin to use (part of paperSize in PhantomJS)
  config.margin = '1cm'

  # The zoom factor (zoomFactor in PhantomJS)
  config.zoom = 1

  # The page orientation ('portrait' or 'landscape') (part of paperSize in PhantomJS)
  config.orientation = 'portrait'

  # The directory where temporary files are stored, including the generated PDF files.
  config.tmpdir = Dir.mktmpdir('shrimp'),

  # How long to wait (in ms) for PhantomJS to load the web page before saving it to a file.
  # Increase this if you need to render very complex pages.
  config.rendering_time = 1_000

  # The timeout for the phantomjs rendering process (in ms).  This needs always to be higher than
  # rendering_time.  If this timeout expires before the job completes, it will cause PhantomJS to
  # abort and exit with an error.
  config.rendering_timeout = 90_000

  # Change the viewport size.  If you are rendering a page that adapts its layout based on the
  # page width and height then you may need to set this to enforce a specific size.  (viewportSize
  # in PhantomJS)
  config.viewport_width  = 600
  config.viewport_height = 600

  # The path to a json configuration file containing command-line options to be used by PhantomJS.
  # Refer to https://github.com/ariya/phantomjs/wiki/API-Reference for a list of valid options.
  # The default options are listed in the Readme.  To use your own file from
  # config/shrimp/config.json in Rails app, you could do this:
  config.command_config_file = Rails.root.join('config/shrimp/config.json')

  # Enable if you want to see details such as the phantomjs command line that it's about to execute.
  config.debug = false

end
```

### Default PhantomJS Command-line Options

These are the PhantomJS options that will be used by default unless you set the
`config.command_config_file` option.

See the PhantomJS [API-Reference](https://github.com/ariya/phantomjs/wiki/API-Reference) for a
complete list of valid options.

```js
{
    "diskCache": false,
    "ignoreSslErrors": false,
    "loadImages": true,
    "outputEncoding": "utf8",
    "webSecurity": true
}
```

## Middleware

Shrimp comes with a middleware that allows users to generate a PDF file of any page on your site
simply by appending .pdf to the URL.

For example, if your site is [example.com](http://example.com) and you go to
http://example.com/report.pdf, the middleware will detect that a PDF is being requested and will
automatically convert the web page at http://example.com/report into a PDF and send that PDF as the
response.

If you only want to allow this for some pages but not all of them, see below for how to add
conditions.

### Middleware Setup

**Non-Rails Rack apps**

```ruby
# in config.ru
require 'shrimp'
use Shrimp::Middleware
```

**Rails apps**

```ruby
# in application.rb or an initializer (Rails 3) or environment.rb (Rails 2)
require 'shrimp'
config.middleware.use Shrimp::Middleware
```

**With Shrimp options**

```ruby
# Options will be passed to Shrimp::Phantom.new
config.middleware.use Shrimp::Middleware, :margin => '0.5cm', :format => 'Letter'
```

**With conditions to limit which paths can be requested in PDF format**

```ruby
# conditions can be regexps (either one or an array)
config.middleware.use Shrimp::Middleware, {}, :only => %r[^/public]
config.middleware.use Shrimp::Middleware, {}, :only => [%r[^/invoice], %r[^/public]]

# conditions can be strings (either one or an array)
config.middleware.use Shrimp::Middleware, {}, :only => '/public'
config.middleware.use Shrimp::Middleware, {}, :only => ['/invoice', '/public']

# conditions can be regexps (either one or an array)
config.middleware.use Shrimp::Middleware, {}, :except => [%r[^/prawn], %r[^/secret]]

# conditions can be strings (either one or an array)
config.middleware.use Shrimp::Middleware, {}, :except => ['/secret']
```

### Polling

To avoid typing up the web server while waiting for the PDF to be rendered (which could create a
deadlock) Shrimp::Middleware starts PDF generation in the background in a separate process and
returns a 503 (Service Unavailable) response immediately.

It also adds a [Retry-After](http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html) response
header, which tells the user's browser that the requested PDF resource is not available yet, but
will be soon, and instructs the browser to try again after a few seconds.  When the same page is
requested again in a few seconds, it will again return a 503 if the PDF is still in the process of
being generated.  This process will repeat until eventually the rendering has completed, at which
point the middleware returns a 200 (OK) response with the PDF itself.

You can adjust both the `polling_offset` (how long to wait before the first retry; default is 1
second) and the `polling_interval` (how long in seconds to wait between retries; default is 1
second).  Example:

```ruby
    config.middleware.use Shrimp::Middleware, :polling_offset => 5, :polling_interval => 1
```

### Caching

To improve performance and avoid having to re-generate the PDF file each time you request a PDF
resource, the existing PDF (that was generated the *first* time a certain URL was requested) will be
reused and sent again immediately if it already exists (for the same requested URL) and was
generated within the TTL.

The default TTL is 1 second, but can be overridden by passing a different `cache_ttl` (in seconds)
to the middleware:

```ruby
    config.middleware.use Shrimp::Middleware, :cache_ttl => 3600, :out_path => "my/pdf/store"
```

To disable this caching entirely and force it to re-generate the PDF again each time a request comes
in, set `cache_ttl` to 0.


### Ajax requests

Here's an example of how to initiate an Ajax request for a PDF resource (using jQuery) and keep
polling the server until it either finishes successfully or returns with a 504 error code.

```js
  var url = '/my_page.pdf'
  var statusCodes = {
    200: function() {
      return window.location.assign(url);
    },
    504: function() {
     console.log("Sorry, the request timed out.")
    },
    503: function(jqXHR, textStatus, errorThrown) {
      var wait;
      wait = parseInt(jqXHR.getResponseHeader('Retry-After'));
      return setTimeout(function() {
        return $.ajax({
          url: url,
          statusCode: statusCodes
        });
      }, wait * 1000);
    }
  }
  $.ajax({
    url: url,
    statusCode: statusCodes
  })

```

## Contributing

1. Fork this repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a pull request (`git pull-request` if you've installed [hub](https://github.com/github/hub))

## Copyright

Shrimp is Copyright © 2012 adeven (Manuel Kniep). It is free software, and may be redistributed
under the terms specified in the LICENSE file.
