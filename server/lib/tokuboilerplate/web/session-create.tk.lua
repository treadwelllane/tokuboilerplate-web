require("santoku.web.version").check("<% return version %>")
local tpl = require("tokuboilerplate.web.templates")
local db = require("tokuboilerplate.db.loaded")

local session_id = ngx.var.cookie_session
if not session_id then
  session_id = db.random_hex(16)
end

ngx.header["Set-Cookie"] = "session=" .. session_id .. "; Path=/; HttpOnly; SameSite=Strict; Max-Age=31536000"
ngx.header["Authorization"] = session_id

db.get_or_create_session(session_id)

ngx.header.content_type = "text/html"
ngx.say(tpl["session-state"]({ has_session = true }))