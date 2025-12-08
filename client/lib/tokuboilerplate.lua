local common = require("tokuboilerplate.common")

local M = {}

function M.hello()
  return "Hello from tokuboilerplate client", common.hello()
end

return M