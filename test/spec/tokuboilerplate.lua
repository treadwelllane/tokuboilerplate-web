local test = require("santoku.test")
local str = require("santoku.string")
local common = require("tokuboilerplate.common")

test("tokuboilerplate root", function()
  str.printf("\n%s\n", common.hello())
end)