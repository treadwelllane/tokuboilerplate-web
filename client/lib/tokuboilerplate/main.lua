local js = require("santoku.web.js")
local str = require("santoku.string")
local sqlite_proxy = require("santoku.web.sqlite.proxy")
local app = require("tokuboilerplate")

local hash_manifest = js.self.HASH_MANIFEST
local function resolve_hashed (path)
  if hash_manifest then
    local name = str.stripprefix(path, "/")
    local hashed = hash_manifest[name]
    if hashed then
      return "/" .. hashed
    end
  end
  return path
end

local bundle_js = resolve_hashed(js.document:querySelector('meta[name="bundle-js"]').content)
sqlite_proxy(bundle_js, function ()
  print(app.hello())
end)
