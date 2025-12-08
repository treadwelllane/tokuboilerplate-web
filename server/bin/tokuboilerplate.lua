local argparse = require("argparse")
local db_mod = require("tokuboilerplate.db")

local parser = argparse()
  :name("tokuboilerplate")
  :description("Admin CLI for the tokuboilerplate database")

parser
  :option("--sqlite", "SQLite database file")
  :args("1")
  :count("1")

parser:command("dump", "Dump all sessions and their numbers")

parser:command("clear", "Clear all numbers from the database")

local args = parser:parse()

local db = db_mod(args.sqlite)

if args["dump"] then

  local sessions = db.db.all("select id, session_id from sessions")()
  for _, session in ipairs(sessions) do
    print(string.format("Session: %s", session.session_id))
    local numbers = db.get_numbers(session.id)
    for _, row in ipairs(numbers) do
      print(string.format("  %d", row.number))
    end
  end

elseif args["clear"] then

  db.db.exec("delete from numbers")
  print("Cleared all numbers")

end