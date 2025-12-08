local sw = require("santoku.web.pwa.sw")
local routes = require("tokuboilerplate.routes")

return sw({
  nonce = "<% return tostring(os.time() %>",
  version = "<% return version %>",
  sqlite = true,
  precache = <% return serialize(client.public_files), false %>,
  routes = routes,
})
