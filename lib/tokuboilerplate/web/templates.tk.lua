<%
  local serialize = require("santoku.serialize")
  local fs = require("santoku.fs")
  local index = require("santoku.web.pwa.index")
  return fs.runfile(fs.join(root_dir, "res/web/template-loader.lua"))(readfile, root_dir, true)
%>
