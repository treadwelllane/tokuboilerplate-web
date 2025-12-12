<%
  local fs = require("santoku.fs")
  local tbl = require("santoku.table")
  local index = require("santoku.web.pwa.index")
  local partials = fs.runfile(fs.join(root_dir, "res/web/template-loader.lua"))(readfile, root_dir)
  bundle_js_hashed = "/" .. hashed("bundle.js")
  bundle_wasm_hashed = "/" .. hashed("bundle.wasm")
  index_html = index(tbl.merge({}, client.pwa, {
    sw = true,
    initial = false,
    head = [[
      <meta name="htmx-config" content='{"defaultSwapStyle":"morph:outerHTML"}'>
      <meta name="bundle-js" content="{{bundle\.js}}">
      <link rel="stylesheet" href="{{index\.css}}">
      <script src="{{htmx\.min\.js}}"></script>
      <script src="{{idiomorph-ext\.min\.js}}"></script>
      <script src="{{bundle\.js}}"></script>
    ]],
    body = partials["body-app"](),
  }))
%>

local js = require("santoku.web.js")
local val = require("santoku.web.val")
local err = require("santoku.error")
local async = require("santoku.async")
local mch = require("santoku.mustache")
local rand = require("santoku.random")

local Headers = js.Headers
local Request = js.Request

local index_html = mch([[<% return index_html, false %>]])(val.lua(js.HASH_MANIFEST, true))

return function (db, http)

  local function do_sync (authorization, page, done)
    return async.pipe(function (next)
      return db.get_last_sync(next)
    end, function (next, since)
      return db.get_changes(function (ok, changes)
        next(ok, since or "0", changes)
      end)
    end, function (next, since, changes)
      local headers = Headers:new()
      headers:set("Content-Type", "application/json")
      headers:set("Authorization", authorization)
      local req = Request:new("/sync?since=" .. since .. "&page=" .. page, val({
        method = "POST",
        headers = headers,
        body = changes
      }))
      return http.fetch(req, {}, next)
    end, function (next, response)
      if not response or not response.ok then
        return next(false)
      end
      return response.body(function (ok0, text)
        return next(ok0, text)
      end)
    end, function (ok, server_changes)
      if not ok then
        return db.get_numbers_with_error_state(page, done)
      end
      return db.complete_sync(server_changes, page, done)
    end)
  end

  return {

    ["^/$"] = function (_, _, _, done)
      return done(true, index_html, "text/html")
    end,

    ["^/numbers$"] = function (_, _, params, done)
      local page = tonumber(params.page) or 1
      return db.get_numbers(page, done)
    end,

    ["^/number/create$"] = function (_, _, _, done)
      return db.create_number_with_state(done)
    end,

    ["^/number/update$"] = function (_, _, params, done)
      err.assert(params.id, "missing id parameter")
      return db.update_number_with_state(params.id, done)
    end,

    ["^/number/delete$"] = function (_, _, params, done)
      err.assert(params.id, "missing id parameter")
      local page = tonumber(params.page) or 1
      return db.delete_number_with_state(params.id, page, function (ok, result)
        if not ok then
          return done(false, result)
        end
        if result.redirect_page then
          return done(true, result.html, nil, { ["HX-Push-Url"] = "/?page=" .. result.redirect_page })
        end
        return done(true, result.html)
      end)
    end,

    ["^/auth/status$"] = function (_, _, _, done)
      return db.get_auth_status(done)
    end,

    ["^/session/delete$"] = function (_, _, _, done)
      return db.delete_session(done)
    end,

    ["^/sync/status$"] = function (_, _, _, done)
      return db.get_sync_status(done)
    end,

    ["^/auto%-sync/toggle$"] = function (_, _, _, done)
      return db.toggle_auto_sync(done)
    end,

    ["^/sync$"] = function (_, _, params, done)
      local page = tonumber(params.page) or 1
      return db.get_authorization(function (ok, auth)
        if not ok then
          return db.get_numbers_with_error_state(page, done)
        end
        if auth then
          return do_sync(auth, page, done)
        end
        auth = rand.alnum(32)
        return db.set_authorization(auth, function (ok2)
          if not ok2 then
            return db.get_numbers_with_error_state(page, done)
          end
          return do_sync(auth, page, done)
        end)
      end)
    end,

  }

end
