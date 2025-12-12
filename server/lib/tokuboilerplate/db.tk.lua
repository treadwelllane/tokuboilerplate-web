<%
  local fs = require("santoku.fs")
  local serialize = require("santoku.serialize")
  local migrations = {}
  for fp in fs.files("res/server/migrations") do
    migrations[fs.basename(fp)] = readfile(fp)
  end
  t_migrations = serialize(migrations, true)
%>

local lsqlite3 = require("lsqlite3")
local sqlite = require("santoku.sqlite")
local sqlite_migrate = require("santoku.sqlite.migrate")

return function (db_file)

  if type(db_file) == "table" then
    return db_file
  end

  local M = {}
  local db = sqlite(lsqlite3.open(db_file))

  db.exec("pragma journal_mode = WAL")
  db.exec("pragma synchronous = NORMAL")
  db.exec("pragma busy_timeout = 30000")
  db.exec("pragma cache_size = -2000")
  db.exec("pragma temp_store = MEMORY")
  db.exec("pragma mmap_size = 268435456")

  sqlite_migrate(db, <% return t_migrations %>) -- luacheck: ignore

  db.exec([[
    create temporary table if not exists records_incoming (
      id text primary key,
      hlc text,
      payload text
    )
  ]])

  M.db = db

  local clear_incoming = db.runner([[
    delete from records_incoming
  ]])

  local populate_incoming = db.runner([[
    insert into records_incoming (id, hlc, payload)
    select
      json_extract(value, '$.id'),
      json_extract(value, '$.hlc'),
      json_extract(value, '$.payload')
    from json_each(?1)
  ]])

  local insert_from_incoming = db.runner([[
    insert or ignore into records (sub, id, hlc, payload)
    select ?1, id, hlc, payload
    from records_incoming
  ]])

  local update_from_incoming = db.runner([[
    update records set
      hlc = i.hlc,
      payload = i.payload
    from records_incoming i
    where records.sub = ?1
      and records.id = i.id
      and i.hlc > records.hlc
  ]])

  local get_changes_excluding_incoming = db.getter([[
    select json_group_array(json_object(
      'id', id,
      'hlc', hlc,
      'payload', json(payload)))
    from records
    where sub = ?1
      and hlc > ?2
      and id not in (select id from records_incoming)
  ]])

  M.sync = function (sub, changes, since)
    return db.transaction(function ()
      clear_incoming()
      if changes then
        populate_incoming(changes)
        insert_from_incoming(sub)
        update_from_incoming(sub)
      end
      return get_changes_excluding_incoming(sub, since)
    end)
  end

  return M

end
