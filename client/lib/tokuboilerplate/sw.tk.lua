<%
  serialize = require("santoku.serialize")
  str = require("santoku.string")
  local fs = require("santoku.fs")
  local mch = require("santoku.mustache")
  local loader = fs.runfile(fs.join(root_dir, "res/web/template-loader.lua"))
  local partials = loader(readfile, root_dir)
  local sw_body = mch(partials["sw-body"], { partials = partials })()
  index_html = require("santoku.web.pwa.index")({
    title = client.opts.title,
    description = client.opts.description,
    theme_color = client.opts.theme_color,
    sw_inline = true,
    bundle = "/bundle.js",
    manifest = "/manifest.json",
    favicon_svg = client.opts.favicon_svg,
    ios_icon = client.opts.ios_icon,
    splash_screens = client.opts.splash_screens,
    head = client.opts.head,
    cached_files = client.opts.cached_files,
    deferred_scripts = client.opts.deferred_scripts,
    body_tag = sw_body,
  })
%>
local sw = require("santoku.web.pwa.sw")
local routes = require("tokuboilerplate.routes")

return sw({
  service_worker_version = <% return tostring(os.time()) %>,
  version_check = <% return version_check and str.quote(version_check) or "nil" %>,
  sqlite = true,
  index_html = [[<% return index_html, false %>]],
  cached_files = <% return serialize(client.opts.cached_files, true), false %>,
  routes = routes,
})
