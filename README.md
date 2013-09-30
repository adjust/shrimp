# Shrimp
[![Build Status](https://travis-ci.org/adeven/shrimp.png?branch=master)](https://travis-ci.org/adeven/shrimp)
Creates PDFs from URLs using phantomjs

Read our [blogpost](http://big-elephants.com/2012-12/pdf-rendering-with-phantomjs/) about how it works.

## Installation

Add this line to your application's Gemfile:

    gem 'shrimp'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install shrimp


### pantomjs

    See http://phantomjs.org/download.html on how to install phatomjs

## Usage

```
require 'shrimp'
url     = 'http://www.google.com'
options = { :margin => "1cm"}
Shrimp::Phantom.new(url, options).to_pdf("~/output.pdf")
```
## Configuration

```
Shrimp.configure do |config|

  # The path to the phantomjs executable
  # defaults to `where phantomjs`
  # config.phantomjs = '/usr/local/bin/phantomjs'

  # the default pdf output format
  # e.g. "5in*7.5in", "10cm*20cm", "A4", "Letter"
  # config.format           = 'A4'

  # the default margin
  # config.margin           = '1cm'

  # the zoom factor
  # config.zoom             = 1

  # the page orientation 'portrait' or 'landscape'
  # config.orientation      = 'portrait'

  # a temporary dir used to store tempfiles
  # config.tmpdir           = Dir.tmpdir

  # the default rendering time in ms
  # increase if you need to render very complex pages
  # config.rendering_time   = 1000

  # change the viewport size.  If you rendering pages that have 
  # flexible page width and height then you may need to set this
  # to enforce a specific size
  # config.viewport_width = 600 
  # config.viewport_height = 600

  # the timeout for the phantomjs rendering process in ms
  # this needs always to be higher than rendering_time
  # config.rendering_timeout       = 90000

  # the path to a json configuration file for command-line options
  # config.command_config_file = "#{Rails.root.join('config', 'shrimp', 'config.json')}"
end
```

### Command Configuration

```
{
    "diskCache": false,
    "ignoreSslErrors": false,
    "loadImages": true,
    "outputEncoding": "utf8",
    "webSecurity": true
}
```

## Middleware

Shrimp comes with a middleware that allows users to get a PDF view of any page on your site by appending .pdf to the URL.

### Middleware Setup

**Non-Rails Rack apps**

    # in config.ru
    require 'shrimp'
    use Shrimp::Middleware

**Rails apps**

    # in application.rb(Rails3) or environment.rb(Rails2)
    require 'shrimp'
    config.middleware.use Shrimp::Middleware

**With Shrimp options**

    # options will be passed to Shrimp::Phantom.new
    config.middleware.use Shrimp::Middleware, :margin => '0.5cm', :format => 'Letter'

**With conditions to limit routes that can be generated in pdf**

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


### Polling

To avoid deadlocks Shrimp::Middleware renders the pdf in a separate process retuning a 503 Retry-After response Header.
you can setup the polling interval and the polling offset in seconds.

    config.middleware.use Shrimp::Middleware, :polling_interval => 1, :polling_offset => 5

### Caching

To avoid rendering the page on each request you can setup some the cache ttl in seconds

    config.middleware.use Shrimp::Middleware, :cache_ttl => 3600, :out_path => "my/pdf/store"


### Ajax requests

To include some fancy Ajax stuff with jquery

```js

 var url = '/my_page.pdf'
 var statusCodes = {
      200: function() {
        return window.location.assign(url);
      },
      504: function() {
       console.log("Shit's beeing wired")
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

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Copyright
Shrimp is Copyright © 2012 adeven (Manuel Kniep). It is free software, and may be redistributed under the terms
specified in the LICENSE file.
