var
  webpage = require('webpage'),
  fs      = require('fs'),
  system  = require('system'),
  margin          = system.args[5] || '0cm',
  orientation     = system.args[6] || 'portrait',
  cookie_file     = system.args[7],
  render_time     = system.args[8] || 10000 ,
  time_out        = system.args[9] || 90000 ,
  viewport_width  = system.args[10] || 600,
  viewport_height = system.args[11] || 600,
  redirects_num   = system.args[12] || 0,
  cookies = {},
  address, output, size;

function error(msg) {
  msg = msg || 'Unknown error';
  console.log(msg);
  phantom.exit(1);
  throw msg;
}

function print_usage() {
  console.log('Usage: rasterize.js URL filename [paperwidth*paperheight|paperformat] [zoom] [margin] [orientation] [cookie_file] [render_time] [time_out] [viewport_width] [viewport_height] [max_redirects_count]');
  console.log('  paper (pdf output) examples: "5in*7.5in", "10cm*20cm", "A4", "Letter"');
}

window.setTimeout(function () {
  error("No result within " + time_out + "ms. Aborting PhantomJS.");
}, time_out);

function renderUrl(url, output, options) {
  options = options || {};

  var statusCode,
      page = webpage.create();

  for (var k in options) {
    if (options.hasOwnProperty(k)) {
      page[k] = options[k];
    }
  }

  // determine the statusCode
  page.onResourceReceived = function (resource) {
    if (resource.url == url) {
      console.log('response: ' + JSON.stringify(resource))
      statusCode = resource.status;
    }
  };

  page.onResourceError = function (resourceError) {
    // Log the error but allow normal "Unable to load the page." handling to occur too so that we
    // can get and report the actual HTTP status code. (resourceError.errorCode just returns a code
    // from http://doc.qt.io/qt-4.8/qnetworkreply.html#NetworkError-enum)
    console.log(resourceError.errorString);
  };

  if (redirects_num > 0) {
    page.onNavigationRequested = function (redirect_url, type, willNavigate, main) {
      if (main) {
        if (redirect_url !== url) {
          page.close();

          if (redirects_num-- >= 0) {
            renderUrl(redirect_url, output, options);
          } else {
            error(url + ' redirects to ' + redirect_url + ' after maximum number of redirects reached');
          }
        }
      }
    };
  }

  page.open(url, function (status) {
    if (status !== 'success' || (statusCode != 200 && statusCode != null)) {
      if (fs.exists(output)) {
        fs.remove(output);
      }
      try {
        fs.touch(output);
      } catch (e) {
        console.log(e);
      }

      error('Unable to load the page. (HTTP ' + statusCode + ') (URL: ' + url + ')');
    } else {
     /* Check whether the loaded page overwrites the header/footer setting,
        i.e. whether a PhantomJSPriting object exists. Use that then instead
        of our defaults above.
        See https://github.com/ariya/phantomjs/blob/master/examples/printheaderfooter.js#L66
      */
      window.setTimeout(function () {
        if (page.evaluate(function(){return typeof PhantomJSPrinting == "object";})) {
          paperSize = page.paperSize;
          paperSize.header.height = page.evaluate(function() {
            return PhantomJSPrinting.header.height;
          });
          paperSize.header.contents = phantom.callback(function(pageNum, numPages) {
            return page.evaluate(function(pageNum, numPages){return PhantomJSPrinting.header.contents(pageNum, numPages);}, pageNum, numPages);
          });
          paperSize.footer.height = page.evaluate(function() {
            return PhantomJSPrinting.footer.height;
          });
          paperSize.footer.contents = phantom.callback(function(pageNum, numPages) {
            return page.evaluate(function(pageNum, numPages){return PhantomJSPrinting.footer.contents(pageNum, numPages);}, pageNum, numPages);
          });
          page.paperSize = paperSize;
        }
        page.render(output);
        console.log('rendered to: ' + output, new Date().getTime());
        phantom.exit();
      }, render_time);
    }
  });
}

if (cookie_file) {
  try {
    f = fs.open(cookie_file, "r");
    cookies = JSON.parse(f.read());
    fs.remove(cookie_file);
  } catch (e) {
    console.log(e);
  }
  phantom.cookiesEnabled = true;
  phantom.cookies = cookies;
}

if (system.args.length < 3 || system.args.length > 13) {
  print_usage() && phantom.exit(2);
} else {
  address = system.args[1];
  output  = system.args[2];

  page_options = {
    viewportSize: {
      width:  viewport_width,
      height: viewport_height
    }
  };

  if (system.args.length > 3 && system.args[2].substr(-4) === ".pdf") {
    size = system.args[3].split('*');
    header = { height: '1cm', contents: phantom.callback(function(pageNum, numPages) { return ""; }) };
    footer = { height: '1cm', contents: phantom.callback(function(pageNum, numPages) { return ""; }) };
    page_options.paperSize = size.length === 2 ? { width:size[0], height:size[1], margin:'0px', header: header, footer: footer }
      : { format:system.args[3], orientation:orientation, margin:margin, header: header, footer: footer };
  }
  if (system.args.length > 4) {
    page_options.zoomFactor = system.args[4];
  }

  renderUrl(address, output, page_options);
}
