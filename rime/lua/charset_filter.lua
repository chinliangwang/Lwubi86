-- Character range filter for lightWubi86.
--
-- The generated tables live under lua/charset/. This filter only handles
-- single-character candidates; phrases are passed through so word
-- candidates are not over-filtered.
--
-- Runtime TSV files are parsed once per translation (they are tiny). When the
-- current code has no frequency-order override, candidates are yielded lazily
-- so large completion lists do not have to be buffered before the first page.

local M = {}

local RUNTIME_DELETED_FILE = "lua/runtime_deleted.tsv"
local RUNTIME_ORDER_FILE = "lua/runtime_order.tsv"

local function join(base, rel)
  if not rel or rel == "" then return nil end
  local sep = package.config:sub(1, 1)
  if rel:match("^/") or rel:match("^%a:[/\\]") then return rel end
  return base .. (base:sub(-1) == sep and "" or sep) .. rel
end

local function user_data_dir()
  if rime_api and rime_api.get_user_data_dir then
    local ok, dir = pcall(rime_api.get_user_data_dir)
    if ok and dir and dir ~= "" then return dir end
  end
  return os.getenv("RIME") or os.getenv("HOME") or "."
end

local function deleted_path()
  return join(user_data_dir(), RUNTIME_DELETED_FILE)
end

local function order_path()
  return join(user_data_dir(), RUNTIME_ORDER_FILE)
end

local function file_size(path)
  local file = path and io.open(path, "r")
  if not file then return -1 end
  local size = file:seek("end")
  file:close()
  return size or 0
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

local function parse_order(path)
  local lists = {}
  local sets = {}
  local file = path and io.open(path, "r")
  if not file then return lists, sets end
  for line in file:lines() do
    local code, text = line:match("^([a-z]+)\t([^\t]+)")
    if code and text then
      local list = lists[code]
      local set = sets[code]
      if not list then
        list = {}
        set = {}
        lists[code] = list
        sets[code] = set
      end
      if not set[text] then
        set[text] = true
        table.insert(list, text)
      end
    end
  end
  file:close()
  return lists, sets
end

local function cached_runtime(env)
  local del_path = deleted_path()
  local ord_path = order_path()
  local del_size = file_size(del_path)
  local ord_size = file_size(ord_path)
  if env._rt_del_size == del_size and env._rt_ord_size == ord_size
      and env._rt_deleted and env._rt_order_lists then
    return env._rt_deleted, env._rt_order_lists, env._rt_order_sets
  end
  env._rt_deleted = parse_deleted(del_path)
  env._rt_order_lists, env._rt_order_sets = parse_order(ord_path)
  env._rt_del_size = del_size
  env._rt_ord_size = ord_size
  return env._rt_deleted, env._rt_order_lists, env._rt_order_sets
end

local function load_charset(path)
  local set = {}
  local count = 0
  local file = path and io.open(path, "r")
  if not file then return set, count end

  for line in file:lines() do
    for _, cp in utf8.codes(line) do
      set[cp] = true
      count = count + 1
    end
  end
  file:close()
  return set, count
end

local function candidate_codepoint(text)
  local only_cp = nil
  local count = 0
  for _, cp in utf8.codes(text or "") do
    count = count + 1
    if count > 1 then return nil end
    only_cp = cp
  end
  return only_cp
end

local function is_cjk_codepoint(cp)
  return (cp >= 0x3400 and cp <= 0x4DBF)
      or (cp >= 0x4E00 and cp <= 0x9FFF)
      or (cp >= 0xF900 and cp <= 0xFAFF)
      or (cp >= 0x20000 and cp <= 0x2A6DF)
      or (cp >= 0x2A700 and cp <= 0x2B73F)
      or (cp >= 0x2B740 and cp <= 0x2B81F)
      or (cp >= 0x2B820 and cp <= 0x2CEAF)
      or (cp >= 0x2CEB0 and cp <= 0x2EBEF)
      or (cp >= 0x30000 and cp <= 0x3134F)
end

local function active_set(env)
  local ctx = env.engine.context
  if ctx:get_option("charset_gb18030") then
    return env.gb18030_map, env.gb18030_count
  end
  if ctx:get_option("charset_gbk") then
    return env.gbk_map, env.gbk_count
  end
  return env.common_map, env.common_count
end

local function keep_candidate(set, deleted, cand)
  local code = cand.preedit
  local text = cand.text
  if code and text then
    local by_code = deleted[code]
    if by_code and by_code[text] then
      return false
    end
  end
  local cp = candidate_codepoint(text)
  if cp and is_cjk_codepoint(cp) and not set[cp] then
    return false
  end
  return true
end

function M.init(env)
  local cfg = env.engine.schema.config
  local base = user_data_dir()

  local common_rel = cfg:get_string("charset/files/common") or "lua/charset/common.txt"
  local gbk_rel = cfg:get_string("charset/files/gbk") or "lua/charset/gbk.txt"
  local gb18030_rel = cfg:get_string("charset/files/gb18030") or "lua/charset/gb18030.txt"

  env.common_map, env.common_count = load_charset(join(base, common_rel))
  env.gbk_map, env.gbk_count = load_charset(join(base, gbk_rel))
  env.gb18030_map, env.gb18030_count = load_charset(join(base, gb18030_rel))
  cached_runtime(env)
end

function M.func(input, env)
  local set, count = active_set(env)

  -- Fail open if a charset table cannot be loaded, so input never collapses to
  -- no menu because of a damaged local file.
  if not set or count == 0 then
    for cand in input:iter() do yield(cand) end
    return
  end

  local deleted, order_lists, order_sets = cached_runtime(env)
  local code = nil
  local ordered_list = nil
  local ordered_set = nil
  local lazy = nil
  local promoted = {}
  local normal = {}

  for cand in input:iter() do
    if keep_candidate(set, deleted, cand) then
      code = code or cand.preedit
      if lazy == nil then
        ordered_list = (code and order_lists[code]) or nil
        ordered_set = (code and order_sets[code]) or nil
        lazy = not (ordered_list and #ordered_list > 0)
      end
      if lazy then
        yield(cand)
      elseif ordered_set and ordered_set[cand.text] then
        promoted[cand.text] = cand
      else
        table.insert(normal, cand)
      end
    end
  end

  if lazy then
    return
  end
  if ordered_list then
    for _, text in ipairs(ordered_list) do
      if promoted[text] then
        yield(promoted[text])
      end
    end
  end
  for _, cand in ipairs(normal) do
    yield(cand)
  end
end

return M
