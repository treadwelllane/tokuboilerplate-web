local test = require("santoku.test")
local str = require("santoku.string")
local app = require("tokuboilerplate")

test("tokuboilerplate server", function()
  str.printf("\n%s: %s\n", app.hello())
end)