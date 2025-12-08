local test = require("santoku.test")
local str = require("santoku.string")
local app = require("tokuboilerplate")

test("tokuboilerplate client", function()
  print(app.hello())
  str.printf("\n%s: %s\n", app.hello())
end)