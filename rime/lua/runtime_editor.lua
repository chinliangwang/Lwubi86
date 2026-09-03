local M = {}

local MAX_RECENT_CHARS = 8
local RUNTIME_WORDS_FILE = "lua/runtime_words.tsv"
local RUNTIME_DELETED_FILE = "lua/runtime_deleted.tsv"
local RUNTIME_ORDER_FILE = "lua/runtime_order.tsv"
local RUNTIME_LOG_FILE = "lua/runtime_editor.log"

local frequency_digit_keys = {
  ["Control+1"] = 0,
  ["Control+2"] = 1,
  ["Control+3"] = 2,
  ["Control+4"] = 3,
  ["Control+5"] = 4,
}

local delete_digit_keys = {
  ["Control+Shift+1"] = 0,
  ["Control+Shift+2"] = 1,
  ["Control+Shift+3"] = 2,
  ["Control+Shift+4"] = 3,
  ["Control+Shift+5"] = 4,
  ["Shift+Control+1"] = 0,
  ["Shift+Control+2"] = 1,
  ["Shift+Control+3"] = 2,
  ["Shift+Control+4"] = 3,
  ["Shift+Control+5"] = 4,
  ["Control+Shift+exclam"] = 0,
  ["Control+Shift+at"] = 1,
  ["Control+Shift+numbersign"] = 2,
  ["Control+Shift+dollar"] = 3,
  ["Control+Shift+percent"] = 4,
  ["Shift+Control+exclam"] = 0,
  ["Shift+Control+at"] = 1,
  ["Shift+Control+numbersign"] = 2,
  ["Shift+Control+dollar"] = 3,
  ["Shift+Control+percent"] = 4,
  -- macOS/Squirrel often reports Ctrl+Shift+number as the shifted symbol.
  ["Control+exclam"] = 0,
  ["Control+at"] = 1,
  ["Control+numbersign"] = 2,
  ["Control+dollar"] = 3,
  ["Control+percent"] = 4,
}

local function current_segment(ctx)
  local comp = ctx.composition
  if not comp or comp:empty() then return nil end
  return comp:back()
end

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

local function log_line(env, message)
  local path = env.runtime_log_path or join(user_data_dir(), RUNTIME_LOG_FILE)
  local file = io.open(path, "a")
  if not file then return end
  file:write(os.date("%Y-%m-%d %H:%M:%S"), "\t", message, "\n")
  file:close()
end

local QUOTE_PAIRS = {
  single = { "‘", "’" },
  double = { "“", "”" },
}
local function next_quote_char(env, which)
  env.quote_toggle = env.quote_toggle or { single = 0, double = 0 }
  local pair = QUOTE_PAIRS[which]
  local idx = env.quote_toggle[which] or 0
  env.quote_toggle[which] = 1 - idx
  return pair[idx + 1]
end
local function quote_kind_for_repr(repr, has_menu)
  if repr == "quotedbl" or repr == "Shift+apostrophe" or repr == "Shift+quotedbl" then
    return "double"
  end
  if repr == "apostrophe" and not has_menu then
    return "single"
  end
  return nil
end

local function bool_text(value)
  return value and "1" or "0"
end

local function log_key_options(env, repr)
  local ctx = env.engine.context
  if repr == "Return" or repr == "KP_Enter"
      or repr == "bracketleft" or repr == "bracketright"
      or repr == "Tab" or repr == "Shift+Tab" or repr == "ISO_Left_Tab"
      or repr == "Shift+Shift_L" or repr == "Shift+Shift_R"
      or repr == "Release+Shift_L" or repr == "Release+Shift_R" then
    log_line(env, "key_options\t" .. repr
      .. "\tcomposing=" .. bool_text(ctx:is_composing())
      .. "\tenter=" .. bool_text(ctx:get_option("enter_commit_code"))
      .. "\tauto_freq=" .. bool_text(ctx:get_option("auto_frequency"))
      .. "\tbrackets=" .. bool_text(ctx:get_option("page_brackets"))
      .. "\ttab=" .. bool_text(ctx:get_option("page_tab"))
      .. "\tshift_select=" .. bool_text(ctx:get_option("shift_candidate_select")))
  end
end

local function split_chars(text)
  local chars = {}
  for _, cp in utf8.codes(text or "") do
    table.insert(chars, utf8.char(cp))
  end
  return chars
end

local function is_cjk_char(text)
  local cp = nil
  local count = 0
  for _, c in utf8.codes(text or "") do
    count = count + 1
    if count > 1 then return false end
    cp = c
  end
  if not cp then return false end
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

local function load_single_char_codes(path)
  local codes = {}
  local fallback = {}
  local file = io.open(path, "r")
  if not file then return codes end

  local in_body = false
  for line in file:lines() do
    line = line:gsub("\r$", "")
    if not in_body then
      in_body = line == "..."
    elseif line ~= "" and not line:match("^#") then
      local text, code = line:match("^([^\t]+)\t([a-z]+)")
      if text and code and is_cjk_char(text) then
        fallback[text] = fallback[text] or code
        if #code == 4 and not codes[text] then
          codes[text] = code
        end
      end
    end
  end
  file:close()

  for text, code in pairs(fallback) do
    codes[text] = codes[text] or code
  end
  return codes
end

local function push_recent(env, text)
  if not text or text == "" then return end
  for _, ch in ipairs(split_chars(text)) do
    local code = env.single_char_codes and env.single_char_codes[ch]
    if code then
      table.insert(env.recent_chars, { text = ch, code = code })
      while #env.recent_chars > MAX_RECENT_CHARS do
        table.remove(env.recent_chars, 1)
      end
      log_line(env, "commit_char\t" .. ch .. "\t" .. code)
    end
  end
end

local function push_recent_commit(env, text, code, source)
  if not text or text == "" then return end
  env.last_commit = { text = text, code = code, source = source or "unknown" }
  log_line(env, "commit_text\t" .. (code or "") .. "\t" .. text .. "\t" .. (source or "unknown"))
end

local function phrase_code(items)
  local n = #items
  if n == 2 then
    return items[1].code:sub(1, 2) .. items[2].code:sub(1, 2)
  end
  if n == 3 then
    return items[1].code:sub(1, 1)
        .. items[2].code:sub(1, 1)
        .. items[3].code:sub(1, 2)
  end
  if n >= 4 then
    return items[1].code:sub(1, 1)
        .. items[2].code:sub(1, 1)
        .. items[3].code:sub(1, 1)
        .. items[n].code:sub(1, 1)
  end
  return nil
end

local function runtime_word_exists(path, code, text)
  local file = io.open(path, "r")
  if not file then return false end
  for line in file:lines() do
    local c, t = line:match("^([a-z]+)\t([^\t]+)")
    if c == code and t == text then
      file:close()
      return true
    end
  end
  file:close()
  return false
end

local function append_unique(path, code, text, tag)
  local file = io.open(path, "r")
  if file then
    for line in file:lines() do
      local c, t = line:match("^([a-z]+)\t([^\t]+)")
      if c == code and t == text then
        file:close()
        return true, "exists"
      end
    end
    file:close()
  end

  file = io.open(path, "a")
  if not file then return false, "cannot_open" end
  file:write(code, "\t", text, "\t", tag or "", "\t", os.date("%Y-%m-%d %H:%M:%S"), "\n")
  file:close()
  return true, "created"
end

local function remove_runtime_word(path, code, text)
  local file = io.open(path, "r")
  if not file then return false, "not_found" end
  local kept = {}
  local removed = false
  for line in file:lines() do
    local c, t = line:match("^([a-z]+)\t([^\t]+)")
    if c == code and t == text then
      removed = true
    else
      table.insert(kept, line)
    end
  end
  file:close()
  if not removed then return false, "not_found" end

  file = io.open(path, "w")
  if not file then return false, "cannot_write" end
  for _, line in ipairs(kept) do
    file:write(line, "\n")
  end
  file:close()
  return true, "removed"
end

local function candidate_code(cand, ctx)
  if cand and cand.preedit and cand.preedit ~= "" then return cand.preedit end
  if ctx and ctx.input and ctx.input ~= "" then return ctx.input end
  return nil
end

local function classify_candidate(cand)
  if not cand or not cand.type then return "unknown" end
  if cand.type == "runtime_word" then return "runtime" end
  if cand.type == "runtime_ordered_runtime" then return "runtime" end
  if cand.type == "table" or cand.type == "user_phrase" then return "main" end
  return cand.type
end

local function target_from_candidate(cand, ctx)
  if not cand then return nil end
  return {
    text = cand.text,
    code = candidate_code(cand, ctx),
    source = classify_candidate(cand),
  }
end

local function is_full_wubi_code(code)
  return code and #code == 4 and code:match("^[a-y]+$") ~= nil
end

local function current_menu_info(ctx)
  local seg = current_segment(ctx)
  if not seg or not seg.menu or seg.menu:empty() then
    return nil, 0, nil
  end
  local count = seg.menu:candidate_count()
  return seg, count, seg.selected_index
end

local function should_auto_frequency(ctx, target, selected_index, candidate_count)
  if not ctx:get_option("auto_frequency") then return false end
  if not target or target.source == "unknown" then return false end
  if target.source ~= "main" and target.source ~= "runtime" then return false end
  if not is_full_wubi_code(target.code) then return false end
  if selected_index == nil or selected_index <= 0 then return false end
  if not candidate_count or candidate_count <= 1 then return false end
  return true
end

local candidate_at

local function remember_pending_selection(env, index)
  local ctx = env.engine.context
  if not ctx:is_composing() then return end
  local _, candidate_count = current_menu_info(ctx)
  local target = target_from_candidate(candidate_at(ctx, index), ctx)
  if not target then return end
  env.pending_commit_target = {
    text = target.text,
    code = target.code,
    source = target.source,
    selected_index = index,
    candidate_count = candidate_count,
  }
end

local select_key_indices = {
  ["1"] = 0,
  ["2"] = 1,
  ["3"] = 2,
  ["4"] = 3,
  ["5"] = 4,
  ["semicolon"] = 1,
  ["apostrophe"] = 2,
}

local function delete_target(env, target, reason)
  if not target or not target.text or target.text == "" or not target.code or target.code == "" then
    log_line(env, "delete_failed\tmissing_target\t" .. (reason or ""))
    return false
  end

  if target.source == "runtime" then
    local ok, status = remove_runtime_word(env.runtime_words_path, target.code, target.text)
    log_line(env, "delete_runtime_" .. status .. "\t" .. target.code .. "\t" .. target.text .. "\t" .. (reason or ""))
    return ok
  end

  local ok, status = append_unique(env.runtime_deleted_path, target.code, target.text, target.source or "main")
  log_line(env, "delete_overlay_" .. status .. "\t" .. target.code .. "\t" .. target.text .. "\t" .. (reason or ""))
  return ok
end

local function write_runtime_order(path, rows)
  local file = io.open(path, "w")
  if not file then return false, "cannot_write" end
  for _, row in ipairs(rows) do
    file:write(row.code, "\t", row.text, "\t", row.source or "", "\t", row.time or "", "\n")
  end
  file:close()
  return true, "written"
end

local function promote_target(env, target, reason)
  if not target or not target.text or target.text == "" or not target.code or target.code == "" then
    log_line(env, "frequency_failed\tmissing_target\t" .. (reason or ""))
    return false
  end

  local rows = {}
  local file = io.open(env.runtime_order_path, "r")
  if file then
    for line in file:lines() do
      local code, text, source, time = line:match("^([a-z]+)\t([^\t]+)\t?([^\t]*)\t?([^\t]*)")
      if code and text and not (code == target.code and text == target.text) then
        table.insert(rows, { code = code, text = text, source = source, time = time })
      end
    end
    file:close()
  end

  table.insert(rows, 1, {
    code = target.code,
    text = target.text,
    source = target.source or "main",
    time = os.date("%Y-%m-%d %H:%M:%S"),
  })

  local ok, status = write_runtime_order(env.runtime_order_path, rows)
  log_line(env, "frequency_" .. status .. "\t" .. target.code .. "\t" .. target.text .. "\t" .. (reason or ""))
  return ok
end

local function clear_after_delete(ctx)
  if ctx.input and ctx.delete_input then
    local len = #ctx.input
    for _ = 1, len do
      pcall(function()
        ctx:delete_input()
      end)
    end
  end

  if ctx.input and ctx.pop_input then
    local len = #ctx.input
    for _ = 1, len do
      pcall(function()
        ctx:pop_input()
      end)
    end
  end

  if ctx.clear then
    pcall(function()
      ctx:clear()
    end)
  end

  if ctx.clear_non_confirmed_composition then
    pcall(function()
      ctx:clear_non_confirmed_composition()
    end)
  end

  if ctx.refresh_menu then
    pcall(function()
      ctx:refresh_menu()
    end)
  end
end

local function clear_composition(ctx)
  clear_after_delete(ctx)
end

local selected_candidate

local function commit_text(env, text)
  if not text or text == "" then return false end
  local ok = pcall(function()
    env.engine:commit_text(text)
  end)
  if ok then
    clear_composition(env.engine.context)
  end
  return ok
end

local function forward_key(env, repr)
  if not KeyEvent then
    log_line(env, "forward_failed\tmissing_KeyEvent\t" .. repr)
    return false
  end
  local ok, event = pcall(function()
    return KeyEvent(repr)
  end)
  if not ok or not event then
    log_line(env, "forward_failed\tbad_event\t" .. repr)
    return false
  end
  local processed = false
  ok = pcall(function()
    processed = env.engine:process_key(event)
  end)
  log_line(env, "forward_" .. (ok and tostring(processed) or "failed") .. "\t" .. repr)
  return ok and processed
end

local function commit_candidate(env, index, reason)
  local ctx = env.engine.context
  local cand = ctx:is_composing() and selected_candidate(ctx, index) or nil
  if not cand or not cand.text or cand.text == "" then
    log_line(env, "candidate_commit_failed\tmissing_candidate\t" .. (reason or ""))
    return false
  end
  log_line(env, "candidate_commit\t" .. tostring(index + 1) .. "\t" .. cand.text .. "\t" .. (reason or ""))
  return commit_text(env, cand.text)
end

local function create_recent_phrase(env, length)
  if #env.recent_chars < length then
    log_line(env, "create_failed\tnot_enough_recent_chars\t" .. tostring(#env.recent_chars))
    return false
  end

  local items = {}
  for i = #env.recent_chars - length + 1, #env.recent_chars do
    table.insert(items, env.recent_chars[i])
  end

  local parts = {}
  for _, item in ipairs(items) do table.insert(parts, item.text) end
  local text = table.concat(parts, "")
  local code = phrase_code(items)
  if not code then
    log_line(env, "create_failed\tno_code\t" .. text)
    return false
  end

  if runtime_word_exists(env.runtime_words_path, code, text) then
    log_line(env, "create_exists\t" .. code .. "\t" .. text)
    return true
  end

  local file = io.open(env.runtime_words_path, "a")
  if not file then
    log_line(env, "create_failed\tcannot_open_runtime_words\t" .. env.runtime_words_path)
    return false
  end
  file:write(code, "\t", text, "\t", os.date("%Y-%m-%d %H:%M:%S"), "\n")
  file:close()
  log_line(env, "create_ok\t" .. code .. "\t" .. text)
  return true
end

function selected_candidate(ctx, index)
  local seg = current_segment(ctx)
  if not seg or not seg.menu or seg.menu:empty() then
    return nil
  end

  if index then
    local count = seg.menu:candidate_count()
    if index < 0 or index >= count then
      return nil
    end
    if seg.menu.get_candidate_at then
      local ok, cand = pcall(function()
        return seg.menu:get_candidate_at(index)
      end)
      if ok and cand then return cand end
    end
    seg.selected_index = index
  end

  if ctx.get_selected_candidate then
    local ok, cand = pcall(function()
      return ctx:get_selected_candidate()
    end)
    if ok then return cand end
  end

  return nil
end

function candidate_at(ctx, index)
  local seg = current_segment(ctx)
  if not seg or not seg.menu or seg.menu:empty() then
    return nil
  end
  local count = seg.menu:candidate_count()
  if index < 0 or index >= count or not seg.menu.get_candidate_at then
    return nil
  end
  local ok, cand = pcall(function()
    return seg.menu:get_candidate_at(index)
  end)
  if ok then return cand end
  return nil
end

local function order_row(target)
  return {
    code = target.code,
    text = target.text,
    source = target.source or "main",
    time = os.date("%Y-%m-%d %H:%M:%S"),
  }
end

local function rewrite_code_order(env, code, ordered_targets, reason)
  if not code or code == "" then
    log_line(env, "frequency_failed\tmissing_code\t" .. (reason or ""))
    return false
  end

  local rows = {}
  local file = io.open(env.runtime_order_path, "r")
  if file then
    for line in file:lines() do
      local c, text, source, time = line:match("^([a-z]+)\t([^\t]+)\t?([^\t]*)\t?([^\t]*)")
      if c and text and c ~= code then
        table.insert(rows, { code = c, text = text, source = source, time = time })
      end
    end
    file:close()
  end

  local seen = {}
  for _, target in ipairs(ordered_targets) do
    if target and target.code == code and target.text and not seen[target.text] then
      table.insert(rows, order_row(target))
      seen[target.text] = true
    end
  end

  local ok, status = write_runtime_order(env.runtime_order_path, rows)
  log_line(env, "frequency_" .. status .. "\t" .. code .. "\t" .. (reason or ""))
  return ok
end

local function step_order_targets(ctx, index)
  local targets = {}
  for i = 0, index do
    table.insert(targets, target_from_candidate(candidate_at(ctx, i), ctx))
  end
  targets[index], targets[index + 1] = targets[index + 1], targets[index]
  return targets
end

function M.func(key, env)
  local ctx = env.engine.context
  local repr = key:repr()
  if repr:match("Control") or repr:match("Shift") then
    log_line(env, "key\t" .. repr)
  end
  log_key_options(env, repr)

  if not key:release()
      and not ctx:get_option("ascii_mode")
      and not ctx:get_option("ascii_punct") then
    local has_menu = false
    pcall(function()
      has_menu = ctx:has_menu()
    end)
    local quote_kind = quote_kind_for_repr(repr, has_menu)
    if quote_kind then
      local quote_char = next_quote_char(env, quote_kind)
      if ctx:is_composing() then
        local cand = selected_candidate(ctx, nil)
        local prefix = cand and cand.text or ""
        commit_text(env, prefix .. quote_char)
      else
        env.engine:commit_text(quote_char)
      end
      return 1
    end
  end

  if repr == "Control+equal" or repr == "Control+plus" then
    if create_recent_phrase(env, 2) then
      return 1
    end
    return 1
  end

  if (repr == "Return" or repr == "KP_Enter") and ctx:is_composing() and ctx:get_option("enter_commit_code") then
    commit_text(env, ctx.input or "")
    return 1
  end

  if ctx:is_composing() and ctx:get_option("page_brackets") then
    if repr == "bracketleft" then
      forward_key(env, "Page_Up")
      return 1
    end
    if repr == "bracketright" then
      forward_key(env, "Page_Down")
      return 1
    end
  end

  if ctx:is_composing() and ctx:get_option("page_tab") then
    if repr == "Tab" then
      forward_key(env, "Page_Down")
      return 1
    end
    if repr == "Shift+Tab" or repr == "ISO_Left_Tab" then
      forward_key(env, "Page_Up")
      return 1
    end
  end

  if ctx:is_composing() and ctx:get_option("shift_candidate_select") then
    if repr == "Shift+Shift_L" then
      commit_candidate(env, 1, "shift_left")
      return 1
    end
    if repr == "Shift+Shift_R" then
      commit_candidate(env, 2, "shift_right")
      return 1
    end
  end

  -- Ctrl+- 删除刚上屏词。Rime 能稳定提供的是“删除当前
  -- 候选/用户词频”能力；在候选窗存在时先映射到当前候选删除。
  if repr == "Control+minus" then
    if delete_target(env, env.last_commit, "last_commit") then
      clear_after_delete(ctx)
      return 1
    end
    return 1
  end

  -- Ctrl+序号 手动调频。默认“调到当前编码最前”；
  -- 打开 manual_frequency_step 后改为只前移一个位置。
  local frequency_index = frequency_digit_keys[repr]
  if frequency_index ~= nil then
    local cand = ctx:is_composing() and selected_candidate(ctx, frequency_index) or nil
    local target = target_from_candidate(cand, ctx)
    local step_mode = ctx:get_option("manual_frequency_step")
    if step_mode and target and frequency_index > 0 then
      if rewrite_code_order(env, target.code, step_order_targets(ctx, frequency_index), "candidate_" .. tostring(frequency_index + 1) .. "_step") then
        clear_after_delete(ctx)
        return 1
      end
      return 1
    end
    if promote_target(env, target, "candidate_" .. tostring(frequency_index + 1)) then
      clear_after_delete(ctx)
      return 1
    end
    return 1
  end

  -- Ctrl+Shift+序号 删除候选。只在有候选窗时接管，避免无候
  -- 选时影响 Rime 默认的状态切换快捷键。
  local index = delete_digit_keys[repr]
  if index ~= nil then
    local cand = ctx:is_composing() and selected_candidate(ctx, index) or nil
    if delete_target(env, target_from_candidate(cand, ctx), "candidate_" .. tostring(index + 1)) then
      clear_after_delete(ctx)
      return 1
    end
    return 1
  end

  local select_index = select_key_indices[repr]
  if select_index ~= nil then
    remember_pending_selection(env, select_index)
  end

  return 2
end

function M.init(env)
  local base = user_data_dir()
  env.runtime_words_path = join(base, RUNTIME_WORDS_FILE)
  env.runtime_deleted_path = join(base, RUNTIME_DELETED_FILE)
  env.runtime_order_path = join(base, RUNTIME_ORDER_FILE)
  env.runtime_log_path = join(base, RUNTIME_LOG_FILE)
  env.recent_chars = {}
  env.last_commit = nil
  env.pending_commit_target = nil
  env.quote_toggle = { single = 0, double = 0 }
  env.single_char_codes = load_single_char_codes(join(base, "light_wubi86.dict.yaml"))
  log_line(env, "init\tsingle_char_codes_loaded")

  env.commit_connection = env.engine.context.commit_notifier:connect(function(ctx)
    local text = ctx:get_commit_text()
    local cand = ctx:get_selected_candidate()
    local _, candidate_count, selected_index = current_menu_info(ctx)
    local pending = env.pending_commit_target
    env.pending_commit_target = nil
    push_recent(env, text)
    if cand then
      local target = target_from_candidate(cand, ctx)
      target.text = text
      if pending and pending.text == target.text then
        target.code = pending.code or target.code
        target.source = pending.source or target.source
        selected_index = pending.selected_index or selected_index
        candidate_count = pending.candidate_count or candidate_count
      end
      if should_auto_frequency(ctx, target, selected_index, candidate_count) then
        promote_target(env, target, "auto_candidate_" .. tostring(selected_index + 1))
      end
      push_recent_commit(env, target.text, target.code, target.source)
    elseif pending and pending.text == text then
      if should_auto_frequency(ctx, pending, pending.selected_index, pending.candidate_count) then
        promote_target(env, pending, "auto_candidate_" .. tostring(pending.selected_index + 1))
      end
      push_recent_commit(env, text, pending.code, pending.source)
    else
      push_recent_commit(env, text, nil, "unknown")
    end
  end)
end

function M.fini(env)
  if env.commit_connection then
    env.commit_connection:disconnect()
  end
end

return M
