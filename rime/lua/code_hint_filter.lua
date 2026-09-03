-- Lightweight Wubi code hints for lightWubi86.
--
-- Shows Wubi codes beside candidates while using Z + pinyin auxiliary
-- input, and progressive code hints for normal Wubi input.
-- This filter uses a compact build-time text -> preferred Wubi code table and
-- only annotates the first few candidates. It avoids the earlier heavier path
-- that parsed the full dictionary at runtime.

local M = {}

local HINT_FILE = "lua/code_hint/wubi_hint.tsv"
local MAX_HINTED_CANDIDATES = 10

local function join(base, rel)
  local sep = package.config:sub(1, 1)
  return base .. (base:sub(-1) == sep and "" or sep) .. rel
end

local function user_data_dir()
  if rime_api and rime_api.get_user_data_dir then
    local ok, dir = pcall(rime_api.get_user_data_dir)
    if ok and dir and dir ~= "" then return dir end
  end
  return os.getenv("HOME") or "."
end

local function load_codes(path)
  local map = {}
  local file = io.open(path, "r")
  if not file then return map end

  for line in file:lines() do
    line = line:gsub("\r$", "")
    if line ~= "" and not line:match("^#") then
      local text, code = line:match("^([^\t]+)\t([a-z]+)$")
      if text and code and not map[text] then map[text] = code end
    end
  end
  file:close()
  return map
end

local function shadow(cand, comment)
  if not comment or comment == "" then return cand end
  if ShadowCandidate then
    local ok, result = pcall(function()
      return ShadowCandidate(cand, cand.type, cand.text, comment)
    end)
    if ok and result then return result end
  end
  pcall(function()
    cand.comment = comment
  end)
  return cand
end

function M.init(env)
  env.codes = load_codes(join(user_data_dir(), HINT_FILE))
end

local function is_wubi_input(input)
  return input and input:match("^[a-y][a-z]*$") and #input < 4
end

local function is_single_text(text)
  return text and utf8.len(text) == 1
end

local function progressive_comment(full_code, current, index, cand)
  if not full_code or not current or full_code == "" or current == "" then
    return nil
  end
  if full_code:sub(1, #current) ~= current or #full_code <= #current then
    return nil
  end

  -- Leave the first three one-key short-code characters without extra text
  -- comments; Squirrel cannot color individual candidates.
  if #current == 1 and index <= 3 and is_single_text(cand.text) then
    return nil
  end

  if #current == 1 then
    return full_code
  end
  return full_code:sub(#current + 1)
end

function M.func(input, env)
  local ctx = env.engine.context
  local current = ctx.input or ""
  local pinyin_mode = current:sub(1, 1) == "z"
  local wubi_mode = is_wubi_input(current)

  if not pinyin_mode and not wubi_mode then
    for cand in input:iter() do yield(cand) end
    return
  end

  local count = 0

  for cand in input:iter() do
    count = count + 1
    if count > MAX_HINTED_CANDIDATES then
      yield(cand)
    else
      local full_code = env.codes[cand.text]
      local comment = nil
      if pinyin_mode then
        comment = full_code or cand.comment
      elseif wubi_mode then
        comment = progressive_comment(full_code, current, count, cand) or cand.comment
      end
      yield(shadow(cand, comment))
    end
  end
end

return M
