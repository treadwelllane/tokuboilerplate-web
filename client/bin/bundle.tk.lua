local js = require("santoku.web.js")
local global = js.self
local has_registration = global.registration ~= nil
local has_document = global.document ~= nil
if has_registration then
  return require("tokuboilerplate.sw")
elseif not has_document then
  return require("tokuboilerplate.db")
else
  return require("tokuboilerplate.main")
end
