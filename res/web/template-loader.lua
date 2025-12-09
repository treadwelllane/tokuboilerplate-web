local fs = require("santoku.fs")
local str = require("santoku.string")
local mch = require("santoku.mustache")
local serialize = require("santoku.serialize")

return function (readfile, root_dir, runtime)
  local tpl_dir = fs.join(root_dir, "res/web/templates")
  local tpl = {}
  for path, tp in fs.files(tpl_dir, true) do
    if tp == "file" then
      local key = str.match(path, "^.*/res/web/templates/(.*)%.[^.]+$")
      if key then
        tpl[str.gsub(key, "/", ".")] = readfile(path)
      end
    end
  end
  if not runtime then
    for k, v in pairs(tpl) do
      tpl[k] = mch(v, { partials = tpl })
    end
    return tpl
  else
    return mch([[
      local mch = require("santoku.mustache")
      local tpl = {{{embed}}}
      for k, v in pairs(tpl) do
        tpl[k] = mch(v, { partials = tpl })
      end
      return tpl
    ]])({ embed = serialize(tpl) })
  end
end
