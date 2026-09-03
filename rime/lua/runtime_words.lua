-- Runtime user-created words for lightWubi86.
--
-- This translator reads a small TSV file maintained by runtime_editor.lua.
-- It deliberately avoids Rime userdb so user-created words do not change the
-- baseline dictionary order through automatic frequency updates.
-- Files are parsed once and reused until their size changes.

local M = {}

local RUNTIME_WORDS_FILE = "lua/runtime_words.tsv"
local RUNTIME_DELETED_FILE = "lua/runtime_deleted.tsv"

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

local function runtime_words_path()
  return join(user_data_dir(), RUNTIME_WORDS_FILE)
end

local function runtime_deleted_path()
  return join(user_data_dir(), RUNTIME_DELETED_FILE)
end

local function file_size(path)
  local file = path and io.open(path, "r")
  if not file then return -1 end
  local size = file:seek("end")
  file:close()
  return size or 0
end

local function parse_words(path)
  local by_code = {}
  local file = path and io.open(path, "r")
  if not file then return by_code end
  for line in file:lines() do
    local code, text = line:match("^([a-z]+)\t([^\t]+)")
    if code and text then
      local list = by_code[code]
      if not list then
        list = {}
        by_code[code] = list
      end
      table.insert(list, text)
    end
  end
  file:close()
  return by_code
end

local function parse_deleted(path)
  local map = {}
  local file = path and io.open(path, "r")
  if not file then return map end
  for line in file:lines() do
    local code, text = line:match("^([a-z]+)\t([^\t]+)")
    if code and text then
      local by_code = map[code]
      if not by_code then
        by_code = {}
        map[code] = by_code
      end
      by_code[text] = true
    end
  end
  file:close()
  return map
end

local function cached_tables(env)
  local words_path = runtime_words_path()
  local deleted_path = runtime_deleted_path()
  local words_size = file_size(words_path)
  local deleted_size = file_size(deleted_path)
  if env._rw_words_size == words_size and env._rw_deleted_size == deleted_size
      and env._rw_words and env._rw_deleted then
    return env._rw_words, env._rw_deleted
  end
  env._rw_words = parse_words(words_path)
  env._rw_deleted = parse_deleted(deleted_path)
  env._rw_words_size = words_size
  env._rw_deleted_size = deleted_size
  return env._rw_words, env._rw_deleted
end

function M.init(env)
  cached_tables(env)
end

function M.func(input, seg, env)
  if not input or input == "" or input:sub(1, 1) == "z" then
    return
  end

  local words, deleted = cached_tables(env)
  local list = words[input]
  if not list then
    return
  end

  local seen = {}
  local deleted_for_code = deleted[input]
  for _, text in ipairs(list) do
    if text and not seen[text] and not (deleted_for_code and deleted_for_code[text]) then
      seen[text] = true
      yield(Candidate("runtime_word", seg.start, seg._end, text, "造词 " .. input))
    end
  end
end

return M
