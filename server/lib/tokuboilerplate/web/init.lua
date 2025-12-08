local env = require("santoku.env")
local db_file = env.var("DB_FILE") or "tokuboilerplate.db"
package.loaded["tokuboilerplate.db.loaded"] = require("tokuboilerplate.db")(db_file)