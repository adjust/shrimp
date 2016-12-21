var page = require('webpage').create(),
  fs = require('fs'),
  system = require('system'),
  margin = system.args[5] || '0cm',
  orientation = system.args[6] || 'portrait',
  cookie_file = system.args[7] ,
  render_time = system.args[8] || 10000 ,
  time_out = system.args[9] || 90000 ,
  viewport_width = system.args[10] || 600,
  viewport_height= system.args[11] || 600,
  cookies = {},
  address, output, size, statusCode;

window.setTimeout(function () {
  console.log("No result within " + time_out + "ms. Aborting PhantomJS.");
  phantom.exit(1);
}, time_out);

try {
  f = fs.open(cookie_file, "r");
  cookies = JSON.parse(f.read());
  fs.remove(cookie_file)
} catch (e) {
  console.log(e);
}
phantom.cookiesEnabled = true;
phantom.cookies = cookies;

if (system.args.length < 3 || system.args.length > 12) {
  console.log('Usage: rasterize.js URL filename [paperwidth*paperheight|paperformat] [zoom] [margin] [orientation] [cookie_file] [render_time] [time_out] [viewport_width] [viewport_height]');
  console.log('  paper (pdf output) examples: "5in*7.5in", "10cm*20cm", "A4", "Letter"');
  phantom.exit(1);
} else {
  address = system.args[1];
  output = system.args[2];
  page.viewportSize = { width: viewport_width, height: viewport_height };
  if (system.args.length > 3 && system.args[2].substr(-4) === ".pdf") {
    size = system.args[3].split('*');
    header = { height: '1cm', contents: phantom.callback(function(pageNum, numPages) { return ""; }) };
    footer = { height: '1cm', contents: phantom.callback(function(pageNum, numPages) { return ""; }) };
    page.paperSize = size.length === 2 ? { width:size[0], height:size[1], margin:'0px', header: header, footer: footer }
      : { format:system.args[3], orientation:orientation, margin:margin, header: header, footer: footer };
  }
  if (system.args.length > 4) {
    page.zoomFactor = system.args[4];
  }

  // determine the statusCode
  page.onResourceReceived = function (resource) {
    if (resource.url == address) {
      console.log('response: ' + JSON.stringify(resource))
      statusCode = resource.status;
    }
  };

  page.open(address, function (status) {
    if (status !== 'success' || (statusCode != 200 && statusCode != null)) {
      console.log(statusCode, 'Unable to load the address!');
      if (fs.exists(output)) {
        fs.remove(output);
      }
      try {
        fs.touch(output);
      }
      catch (e) {
        phantom.exit(1);
        throw e
      }
      phantom.exit(1);
    } else {
       /* check whether the loaded page overwrites the header/footer setting,
          i.e. whether a PhantomJSPriting object exists. Use that then instead
          of our defaults above.
          example:
          <html>
            <head>
              <script type="text/javascript">
                var PhantomJSPrinting = {
                  header: {
                      height: "1cm",
                      contents: function(pageNum, numPages) { return pageNum + "/" + numPages; }
                  },
                  footer: {
                      height: "1cm",
                      contents: function(pageNum, numPages) { return pageNum + "/" + numPages; }
                  }
                };
              </script>
            </head>
            <body><h1>asdfadsf</h1><p>asdfadsfycvx</p></body>
        </html>
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
