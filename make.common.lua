local fs = require("santoku.fs")
local num = require("santoku.num")
local str = require("santoku.string")
local arr = require("santoku.array")
local sys = require("santoku.system")

-- iOS icon/splash screen sizes (width, height, pixel ratio)
local icon_sizes = { 192, 512 }
local apple_icon_size = 180
local splash_screens = {
  { 430, 932, 3 }, -- iPhone 14 Pro Max
  { 393, 852, 3 }, -- iPhone 14 Pro
  { 428, 926, 3 }, -- iPhone 14 Plus, 13 Pro Max, 12 Pro Max
  { 390, 844, 3 }, -- iPhone 14, 13, 13 Pro, 12, 12 Pro
  { 375, 812, 3 }, -- iPhone 13 mini, 12 mini, X, XS, 11 Pro
  { 414, 896, 3 }, -- iPhone 11 Pro Max, XS Max
  { 414, 896, 2 }, -- iPhone 11, XR
  { 414, 736, 3 }, -- iPhone 8 Plus
  { 375, 667, 2 }, -- iPhone SE, 8
  { 320, 568, 2 }, -- iPhone SE (1st gen)
  { 1024, 1366, 2 }, -- iPad Pro 12.9"
  { 834, 1194, 2 }, -- iPad Pro 11"
  { 820, 1180, 2 }, -- iPad Air
  { 810, 1080, 2 }, -- iPad 10th gen
  { 768, 1024, 2 }, -- iPad mini, iPad
}

return {
  env = {

    name = "tokuboilerplate",
    version = "0.0.1-1",
    dependencies = {
      "lua == 5.1",
      "santoku >= 0.0.314-1",
    },
    build = {
      dependencies = {
        "santoku-web >= 0.0.404-1",
      }
    },

    server = {
      dependencies = {
        "lua == 5.1",
        "santoku >= 0.0.314-1",
        "santoku-web >= 0.0.404-1",
        "santoku-mustache >= 0.0.14-1",
        "santoku-sqlite >= 0.0.29-1",
        "santoku-sqlite-migrate >= 0.0.19-1",
        "lsqlite3 >= 0.9.6-1",
        "argparse >= 0.7.1-1",
      },
    },

    client = {
      files = true,
      dependencies = {
        "lua == 5.1",
        "santoku >= 0.0.314-1",
        "santoku-web >= 0.0.404-1",
        "santoku-http >= 0.0.19-1",
        "santoku-sqlite >= 0.0.29-1",
        "santoku-sqlite-migrate >= 0.0.19-1",
      },
      rules = {
        ["bundle$"] = {
          ldflags = {
            "--pre-js", "res/pre.js",
            "--extern-pre-js", "res/sqlite/sqlite3.js"
          }
        }
      },
      pwa = {
        title = "tokuboilerplate",
        name = "Toku Boilerplate",
        description = "A web app built with santoku",
        theme_color = "#1e293b",
        background_color = "#f5f5f5",
      },
    },

    nginx = {
      domain = "localhost",
      port = "8080",
      workers = "auto",
      modules = {
        "tokuboilerplate.web.init",
        "tokuboilerplate.web.session-create",
        "tokuboilerplate.web.sync",
      },
    },

    configure = function (submake, envs, register_public_file)
      local client_env = envs.client
      if not client_env then return end
      local function pwa_hashed(filename)
        return "/{{" .. str.gsub(filename, "%.", "\\\\.") .. "}}"
      end
      local htmx_file = fs.join(client_env.public_dir, "htmx.min.js")
      submake.target({ client_env.target }, { htmx_file })
      submake.target({ htmx_file }, {}, function ()
        sys.execute({
          "curl", "-sL", "-o", htmx_file,
          "https://unpkg.com/htmx.org@2.0.7/dist/htmx.min.js"
        })
      end)
      register_public_file("htmx.min.js")
      local idiomorph_file = fs.join(client_env.public_dir, "idiomorph-ext.min.js")
      submake.target({ client_env.target }, { idiomorph_file })
      submake.target({ idiomorph_file }, {}, function ()
        sys.execute({
          "curl", "-sL", "-o", idiomorph_file,
          "https://unpkg.com/idiomorph@0.7.4/dist/idiomorph-ext.min.js"
        })
      end)
      register_public_file("idiomorph-ext.min.js")
      local nested_env = client_env.environment == "test" and "test" or "build"
      local bundler_cwd = fs.join(client_env.work_dir, "build", "default-wasm", nested_env)
      local sqlite3_js = fs.join(bundler_cwd, "res/sqlite/sqlite3.js")
      local bundle_target = fs.join(client_env.bundler_post_dir, "bundle")
      submake.target({ bundle_target }, { sqlite3_js })
      submake.target({ sqlite3_js }, {}, function ()
        fs.mkdirp(fs.dirname(sqlite3_js))
        sys.execute({
          "curl", "-sL", "-o", sqlite3_js,
          "https://unpkg.com/@sqlite.org/sqlite-wasm@3.51.1-build2/sqlite-wasm/jswasm/sqlite3.js"
        })
      end)
      local sqlite3_wasm = fs.join(client_env.public_dir, "sqlite3.wasm")
      submake.target({ client_env.target }, { sqlite3_wasm })
      submake.target({ sqlite3_wasm }, {}, function ()
        fs.mkdirp(fs.dirname(sqlite3_wasm))
        sys.execute({
          "curl", "-sL", "-o", sqlite3_wasm,
          "https://unpkg.com/@sqlite.org/sqlite-wasm@3.51.1-build2/sqlite-wasm/jswasm/sqlite3.wasm"
        })
      end)
      register_public_file("sqlite3.wasm")
      local roboto_weights = { "300", "400", "500", "700" }
      local roboto_urls = {
        ["300"] = "https://fonts.gstatic.com/s/roboto/v32/KFOlCnqEu92Fr1MmSU5fCxc4EsA.woff2",
        ["400"] = "https://fonts.gstatic.com/s/roboto/v32/KFOmCnqEu92Fr1Mu7GxKOzY.woff2",
        ["500"] = "https://fonts.gstatic.com/s/roboto/v32/KFOlCnqEu92Fr1MmEU9fCxc4EsA.woff2",
        ["700"] = "https://fonts.gstatic.com/s/roboto/v32/KFOlCnqEu92Fr1MmWUlfCxc4EsA.woff2",
      }
      for _, weight in ipairs(roboto_weights) do
        local font_file = fs.join(client_env.public_dir, "roboto-" .. weight .. ".woff2")
        submake.target({ client_env.target }, { font_file })
        submake.target({ font_file }, {}, function ()
          sys.execute({
            "curl", "-sL", "-o", font_file, roboto_urls[weight]
          })
        end)
        register_public_file("roboto-" .. weight .. ".woff2")
      end
      local css_out = fs.join(client_env.public_dir, "index.css")
      local css_in = fs.join(client_env.build_dir, "res/index.css")
      submake.target({ client_env.target }, { css_out })
      submake.target({ css_out }, { css_in }, function ()
        sys.execute({
          "tailwindcss",
          "--cwd", client_env.root_dir,
          "-i", css_in,
          "-o", css_out,
          "--minify"
        })
      end)
      register_public_file("index.css")
      local icon_svg_src = fs.join(client_env.work_dir, "res/icon.svg")
      local bg = envs.root.client.pwa.background_color
      local favicon_svg = fs.join(client_env.public_dir, "favicon.svg")
      submake.target({ client_env.target }, { favicon_svg })
      submake.target({ favicon_svg }, { icon_svg_src }, function ()
        fs.writefile(favicon_svg, fs.readfile(icon_svg_src))
      end)
      register_public_file("favicon.svg")
      local manifest_icons = {}
      for _, size in ipairs(icon_sizes) do
        local icon_file = fs.join(client_env.public_dir, "icon-" .. size .. ".png")
        submake.target({ client_env.target }, { icon_file })
        submake.target({ icon_file }, { icon_svg_src }, function ()
          sys.execute({
            "rsvg-convert", "-w", tostring(size), "-h", tostring(size),
            "-o", icon_file, icon_svg_src
          })
        end)
        register_public_file("icon-" .. size .. ".png")
        arr.push(manifest_icons, {
          src = pwa_hashed("icon-" .. size .. ".png"),
          sizes = size .. "x" .. size,
          type = "image/png"
        })
      end
      local apple_icon = fs.join(client_env.public_dir, "apple-touch-icon.png")
      submake.target({ client_env.target }, { apple_icon })
      submake.target({ apple_icon }, { icon_svg_src }, function ()
        sys.execute({
          "rsvg-convert", "-w", tostring(apple_icon_size), "-h", tostring(apple_icon_size),
          "-o", apple_icon, icon_svg_src
        })
      end)
      register_public_file("apple-touch-icon.png")
      local splash_opts = {}
      for _, spec in ipairs(splash_screens) do
        local w, h, dpr = spec[1], spec[2], spec[3]
        local pw, ph = w * dpr, h * dpr
        local splash_name = "splash-" .. w .. "x" .. h .. "@" .. dpr .. "x.png"
        local splash_file = fs.join(client_env.public_dir, splash_name)
        submake.target({ client_env.target }, { splash_file })
        submake.target({ splash_file }, { icon_svg_src }, function ()
          local icon_size = num.min(pw, ph) * 0.3
          sys.execute({
            "sh", "-c", str.format(
              "convert -size %dx%d xc:'%s' \\( %s -resize %dx%d \\) -gravity center -composite %s",
              pw, ph, bg, icon_svg_src, icon_size, icon_size, splash_file
            )
          })
        end)
        register_public_file(splash_name)
        arr.push(splash_opts, {
          width = w,
          height = h,
          dpr = dpr,
          src = pwa_hashed(splash_name)
        })
      end
      envs.root.client.pwa.manifest_icons = manifest_icons
      envs.root.client.pwa.favicon_svg = pwa_hashed("favicon.svg")
      envs.root.client.pwa.ios_icon = pwa_hashed("apple-touch-icon.png")
      envs.root.client.pwa.splash_screens = splash_opts
      if client_env.static_files_ok then
        local all_static_files = { htmx_file, idiomorph_file, sqlite3_wasm, css_out, favicon_svg, apple_icon }
        for _, weight in ipairs(roboto_weights) do
          arr.push(all_static_files, fs.join(client_env.public_dir, "roboto-" .. weight .. ".woff2"))
        end
        for _, size in ipairs(icon_sizes) do
          arr.push(all_static_files, fs.join(client_env.public_dir, "icon-" .. size .. ".png"))
        end
        for _, spec in ipairs(splash_screens) do
          local w, h, dpr = spec[1], spec[2], spec[3]
          arr.push(all_static_files, fs.join(client_env.public_dir, "splash-" .. w .. "x" .. h .. "@" .. dpr .. "x.png"))
        end
        submake.target({ client_env.static_files_ok }, all_static_files, function ()
          fs.touch(client_env.static_files_ok)
        end)
      end
    end,

  }
}
