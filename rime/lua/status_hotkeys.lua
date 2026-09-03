-- Status hotkeys for lightWubi86.
--
--   Ctrl+M           toggle 常用字 <-> GBK
--                    (if currently GB18030, return to 常用字 first)
--   Ctrl+Shift+M     switch to GB18030
--   Ctrl+J           toggle 简体/繁体 (option: simplification)
--
-- BIG5 (Ctrl+Shift+J) is intentionally not implemented.

local M = {}

local Accepted = 1
local Noop = 2

local CHARSET_KEYS = {
  ["Control+m"] = "toggle_common_gbk",
  ["Control+M"] = "toggle_common_gbk",
  ["Control+Shift+m"] = "set_gb18030",
  ["Control+Shift+M"] = "set_gb18030",
  ["Shift+Control+m"] = "set_gb18030",
  ["Shift+Control+M"] = "set_gb18030",
  ["Control+j"] = "toggle_trad",
  ["Control+J"] = "toggle_trad",
}

local function set_charset(ctx, which)
  ctx:set_option("charset_common", which == "common")
  ctx:set_option("charset_gbk", which == "gbk")
  ctx:set_option("charset_gb18030", which == "gb18030")
end

local function current_charset(ctx)
  if ctx:get_option("charset_gb18030") then
    return "gb18030"
  end
  if ctx:get_option("charset_gbk") then
    return "gbk"
  end
  return "common"
end

local function toggle_common_gbk(ctx)
  local cur = current_charset(ctx)
  if cur == "gbk" then
    set_charset(ctx, "common")
  else
    -- common or gb18030 -> gbk when leaving common; from gb18030 go to common
    if cur == "gb18030" then
      set_charset(ctx, "common")
    else
      set_charset(ctx, "gbk")
    end
  end
end

function M.init(env)
end

function M.func(key, env)
  if key:release() then
    return Noop
  end

  local repr = key:repr()
  local action = CHARSET_KEYS[repr]
  if not action then
    return Noop
  end

  local ctx = env.engine.context
  if action == "toggle_common_gbk" then
    toggle_common_gbk(ctx)
    return Accepted
  end
  if action == "set_gb18030" then
    set_charset(ctx, "gb18030")
    return Accepted
  end
  if action == "toggle_trad" then
    ctx:set_option("simplification", not ctx:get_option("simplification"))
    return Accepted
  end

  return Noop
end

return M
