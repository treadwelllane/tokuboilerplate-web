<%
  local fs = require("santoku.fs")
  local serialize = require("santoku.serialize")
  local migrations = {}
  for fp in fs.files("res/client/migrations") do
    migrations[fs.basename(fp)] = readfile(fp)
  end
  t_migrations = serialize(migrations, true)
%>

local sqlite_worker = require("santoku.web.sqlite.worker")
local migrate = require("santoku.sqlite.migrate")
local tpl = require("tokuboilerplate.web.templates")

local PAGE_SIZE = 10

local function format_record (rec, has_auth, just_synced_ids)
  if not rec then return nil end
  rec.no_session = not has_auth
  rec.needs_sync = has_auth and not rec.synced_at
  if just_synced_ids and just_synced_ids[rec.id] then
    rec.just_synced = true
  end
  return rec
end

local function format_records (recs, has_auth, just_synced_ids)
  for i = 1, #recs do
    format_record(recs[i], has_auth, just_synced_ids)
  end
  return recs
end

return sqlite_worker("/tokuboilerplate.db", function (ok, db, callback)

  if not ok then
    return callback(false, db)
  end

  db.exec("pragma locking_mode = EXCLUSIVE")
  db.exec("pragma journal_mode = WAL")
  db.exec("pragma synchronous = NORMAL")
  db.exec("pragma temp_store = MEMORY")
  db.exec("pragma cache_size = -2000")

  migrate(db, <% return t_migrations %>) -- luacheck: ignore

  db.exec([[
    create temporary table if not exists records_incoming (
      id text primary key,
      hlc text,
      payload text
    )
  ]])

  local M = {}

  local get_records_page = db.all([[
    select id, json_extract(payload, '$.number') as number, hlc, synced_at, true as sw
    from records
    where sub = ?1 and json_extract(payload, '$.deleted') is null
    order by rowid desc
    limit ?2 offset ?3
  ]], true)

  local get_record_count = db.getter([[
    select count(*) from records where sub = ?1 and json_extract(payload, '$.deleted') is null
  ]])

  local get_max_local_hlc = db.getter([[
    select max(hlc) from records where sub = ?1
  ]])

  local get_dirty_ids_on_page = db.getter([[
    select json_group_array(id) from (
      select id from records
      where sub = ?1 and json_extract(payload, '$.deleted') is null
      and synced_at is null
      order by rowid desc
      limit ?2 offset ?3
    )
  ]])

  M.get_numbers = function (page)
    page = tonumber(page) or 1
    if page < 1 then page = 1 end
    local sub = M.get_authorization()
    local offset = (page - 1) * PAGE_SIZE
    local total = (sub and get_record_count(sub)) or 0
    local total_pages = math.max(1, math.ceil(total / PAGE_SIZE))
    if page > total_pages then page = total_pages end
    local has_auth = sub ~= nil
    return tpl["number-items"]({
      numbers = format_records((sub and get_records_page(sub, PAGE_SIZE, offset)) or {}, has_auth),
      page = page,
      total_pages = total_pages,
      show_pagination = total_pages > 1,
      has_prev = page > 1,
      has_next = page < total_pages,
      prev_page = page - 1,
      next_page = page + 1
    })
  end

  local function get_numbers_with_synced (page, just_synced_ids)
    page = tonumber(page) or 1
    if page < 1 then page = 1 end
    local sub = M.get_authorization()
    local offset = (page - 1) * PAGE_SIZE
    local total = (sub and get_record_count(sub)) or 0
    local total_pages = math.max(1, math.ceil(total / PAGE_SIZE))
    if page > total_pages then page = total_pages end
    local has_auth = sub ~= nil
    return tpl["number-items"]({
      numbers = format_records((sub and get_records_page(sub, PAGE_SIZE, offset)) or {}, has_auth, just_synced_ids),
      page = page,
      total_pages = total_pages,
      show_pagination = total_pages > 1,
      has_prev = page > 1,
      has_next = page < total_pages,
      prev_page = page - 1,
      next_page = page + 1
    })
  end

  local get_setting = db.getter([[
    select value from settings where key = ?
  ]])

  local set_setting_insert = db.runner([[
    insert or ignore into settings (key, value) values (?1, ?2)
  ]])

  local set_setting_update = db.runner([[
    update settings set value = ?2 where key = ?1
  ]])

  local function set_setting (key, value)
    set_setting_insert(key, value)
    set_setting_update(key, value)
  end

  local function get_authorization ()
    return get_setting("authorization")
  end

  local gen_sub = db.getter([[
    select lower(hex(randomblob(16))) as sub
  ]])

  local function get_or_create_sub ()
    local sub = get_authorization()
    if not sub then
      sub = gen_sub()
      set_setting("authorization", sub)
    end
    return sub
  end

  local gen_hlc = db.getter([[
    insert into hlc_seq values (null)
    returning unixepoch('now', 'subsec') || '.' || printf('%08x', id) as hlc
  ]])

  local create_number = db.getter([[
    insert into records (sub, id, hlc, payload)
    values (?1, (select id from idgen), ?2, json_object('number', abs(random()) % 1000000000))
    returning id, json_extract(payload, '$.number') as number, hlc, synced_at, true as sw
  ]], true)

  local update_number = db.getter([[
    update records set
      payload = json_set(payload, '$.number', abs(random()) % 1000000000),
      hlc = ?3,
      synced_at = null
    where sub = ?1 and id = ?2
    returning id, json_extract(payload, '$.number') as number, hlc, synced_at, true as sw
  ]], true)

  local was_dirty = db.getter([[
    select synced_at is null from records where sub = ?1 and id = ?2
  ]])

  M.create_number = function ()
    local sub = get_or_create_sub()
    local hlc = gen_hlc()
    return tpl["number-item"](format_record(create_number(sub, hlc), true))
  end

  M.update_number = function (id)
    local sub = get_or_create_sub()
    local hlc = gen_hlc()
    return tpl["number-item"](format_record(update_number(sub, id, hlc), true))
  end

  local do_delete_number = db.runner([[
    update records set
      payload = json_set(payload, '$.deleted', true),
      hlc = ?3,
      synced_at = null
    where sub = ?1 and id = ?2
  ]])

  M.delete_number = function (id)
    local sub = get_or_create_sub()
    local hlc = gen_hlc()
    do_delete_number(sub, id, hlc)
  end

  local get_changes = db.getter([[
    select json_group_array(json_object(
      'id', id,
      'hlc', hlc,
      'payload', json(payload)
    )) from records
    where sub = ?1 and synced_at is null
  ]])

  M.get_changes = function ()
    local sub = M.get_authorization()
    if not sub then return "[]" end
    return get_changes(sub)
  end

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
    insert or ignore into records (sub, id, hlc, payload, synced_at)
    select ?1, id, hlc, payload, unixepoch('now', 'subsec')
    from records_incoming
  ]])

  local update_from_incoming = db.runner([[
    update records set
      hlc = i.hlc,
      payload = i.payload,
      synced_at = unixepoch('now', 'subsec')
    from records_incoming i
    where records.sub = ?1 and records.id = i.id
      and i.hlc > records.hlc
  ]])

  local function apply_changes (changes, sub)
    clear_incoming()
    populate_incoming(changes)
    insert_from_incoming(sub)
    update_from_incoming(sub)
  end

  local mark_synced = db.runner([[
    update records set synced_at = unixepoch('now', 'subsec')
    where sub = ?1 and synced_at is null
  ]])

  M.mark_synced = function ()
    local sub = M.get_authorization()
    if not sub then return end
    mark_synced(sub)
  end

  local has_unsynced = db.getter([[
    select exists(select 1 from records where sub = ?1 and synced_at is null)
  ]])

  M.get_authorization = get_authorization

  M.set_authorization = function (auth)
    return set_setting("authorization", auth)
  end

  M.has_authorization = function ()
    return get_authorization() ~= nil
  end

  M.get_last_sync = function ()
    return get_setting("last_sync_at")
  end

  M.set_last_sync = function (ts)
    return set_setting("last_sync_at", ts)
  end

  M.get_auto_sync = function ()
    local result = get_setting("auto_sync")
    return result and result == "1"
  end

  M.set_auto_sync = function (enabled)
    return set_setting("auto_sync", enabled and "1" or "0")
  end

  local function compute_state (has_auth, has_unsynced_val, auto_sync)
    if not has_auth then
      return "error"
    elseif not has_unsynced_val then
      return "synced"
    elseif auto_sync then
      return "pending"
    else
      return "dirty"
    end
  end

  local function get_sync_state_data ()
    local sub = M.get_authorization()
    local auto_sync = M.get_auto_sync()
    return {
      state = compute_state(sub ~= nil, sub and has_unsynced(sub) == 1, auto_sync),
      auto_sync = auto_sync
    }
  end

  M.get_sync_status = function ()
    return tpl["sync-state"](get_sync_state_data())
  end

  M.toggle_auto_sync = function ()
    local current = M.get_auto_sync()
    M.set_auto_sync(not current)
    local data = get_sync_state_data()
    if data.auto_sync and data.state == "pending" then
      data.trigger_sync = true
    end
    return tpl["sync-state"](data)
  end

  local function get_sync_state_oob ()
    local sub = M.get_authorization()
    if not sub then
      return tpl["sync-state"]({
        state = "error",
        oob = true
      })
    end
    local auto_sync = M.get_auto_sync()
    return tpl["sync-state"]({
      state = auto_sync and "pending" or "dirty",
      auto_sync = auto_sync,
      oob = true,
      trigger_sync = auto_sync
    })
  end

  M.create_number_with_state = function ()
    local sub = get_or_create_sub()
    local hlc = gen_hlc()
    create_number(sub, hlc)
    return M.get_numbers(1) .. get_sync_state_oob()
  end

  M.update_number_with_state = function (id)
    local sub = get_or_create_sub()
    local already_dirty = was_dirty(sub, id) == 1
    local hlc = gen_hlc()
    local rec = format_record(update_number(sub, id, hlc), true)
    if not already_dirty then
      rec.just_dirtied = true
    end
    local html = tpl["number-item"](rec)
    return html .. get_sync_state_oob()
  end

  M.delete_number_with_state = function (id, page)
    local sub = get_or_create_sub()
    local hlc = gen_hlc()
    do_delete_number(sub, id, hlc)
    page = tonumber(page) or 1
    local total = get_record_count(sub) or 0
    local redirect_page = nil
    local offset = (page - 1) * PAGE_SIZE
    if offset >= total and page > 1 then
      redirect_page = page - 1
    end
    return {
      html = M.get_numbers(redirect_page or page) .. get_sync_state_oob(),
      redirect_page = redirect_page
    }
  end

  M.get_auth_status = function ()
    return tpl["session-state"]({ has_session = M.has_authorization() })
  end

  M.delete_session = function ()
    M.set_authorization(nil)
    return tpl["session-state"]({ has_session = false })
  end

  M.save_session = function (auth)
    M.set_authorization(auth)
    return tpl["session-state"]({ has_session = true })
  end

  M.get_numbers_with_error_state = function (page)
    local numbers_html = M.get_numbers(page)
    local sync_state = tpl["sync-state"]({
      state = "error",
      auto_sync = M.get_auto_sync(),
      oob = true
    })
    return numbers_html .. sync_state
  end

  M.complete_sync = function (server_changes_json, page)
    local sub = M.get_authorization()
    if not sub then return M.get_numbers_with_error_state(page) end
    page = tonumber(page) or 1
    local offset = (page - 1) * PAGE_SIZE
    local dirty_json = get_dirty_ids_on_page(sub, PAGE_SIZE, offset) or "[]"
    local just_synced_ids = {}
    for id in string.gmatch(dirty_json, '"([^"]+)"') do
      just_synced_ids[id] = true
    end

    apply_changes(server_changes_json, sub)
    mark_synced(sub)

    local max_hlc = get_max_local_hlc(sub)
    if max_hlc then
      M.set_last_sync(tostring(max_hlc))
    end

    local sync_state = tpl["sync-state"]({
      state = "synced",
      auto_sync = M.get_auto_sync(),
      oob = true
    })
    return get_numbers_with_synced(page, just_synced_ids) .. sync_state
  end

  return callback(true, M)

end)
