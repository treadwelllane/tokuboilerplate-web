local common = require("tokuboilerplate.common")

local M = {}

function M.hello()
  return "Hello from tokuboilerplate server", common.hello()
end

return M