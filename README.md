# Shrimp
[![Build Status](https://travis-ci.org/adeven/shrimp.png?branch=master)](https://travis-ci.org/adeven/shrimp)
Creates PDFs from URLs using phantomjs.

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
  # config.format           = 'Letter'

  # the default margin
  # config.margin           = '1cm'

  # the zoom factor
  # config.zoom             = 1

  # the page orientation 'portrait' or 'landscape'
  # config.orientation      = 'portrait'

  # a temporary dir used to store tempfiles
  # config.tmpdir           = Dir.tmpdir

  # whether or not exceptions should explicitly be raised
  # config.fail_silently    = false

  # the maximum time spent rendering a pdf
  # config.rendering_time   = 30000
end
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


### Troubleshooting

*  **Single thread issue:** In development environments it is common to run a
   single server process. This can cause issues because rendering your pdf
   requires phantomjs to hit your server again (for images, js, css).
   This is because the resource requests will get blocked by the initial
   request and the initial request will be waiting on the resource
   requests causing a deadlock.

   This is usually not an issue in a production environment. To get
   around this issue you may want to run a server with multiple workers
   like Passenger or try to embed your resources within your HTML to
   avoid extra HTTP requests.
   
   Example solution (rails / bundler), add unicorn to the development 
   group in your Gemfile `gem 'unicorn'` then run `bundle`. Next, add a 
   file `config/unicorn.conf` with
   
        worker_processes 3
   
   Then to run the app `unicorn_rails -c config/unicorn.conf` (from rails_root)
  (taken from pdfkit readme: https://github.com/pdfkit/pdfkit)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Copyright
Shrimp is Copyright © 2012 adeven (Manuel Kniep). It is free software, and may be redistributed under the terms
specified in the LICENSE file.
