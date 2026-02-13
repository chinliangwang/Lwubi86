-- 严格字符集过滤（GB2312 / GBK / ALL）
-- 设计：
--  - 两个布尔开关：GB2312、GBK；GB2312优先，其次GBK；都关=全集
--  - 仅对 table 翻译器候选做过滤（避免影响标点映射/符号输入）
--  - 过滤规则：候选文本中任意非 ASCII 字符不在 GB2312 字表中 → 过滤
--  - 字表加载失败 → 安全放行，避免“打不出字”

local M = {}

-- 简易 join
local function join(base, rel)
  if not rel or rel == "" then return nil end
  local sep = package.config:sub(1,1)
  if rel:match("^/") or rel:match("^%a:[/\\]") then return rel end
  return base .. (base:sub(-1) == sep and "" or sep) .. rel
end

-- 把字符集文件加载为 codepoint->true 的哈希表
local function load_charset(path)
  local t = {}
  local fh = path and io.open(path, "r")
  if not fh then return nil end
  for line in fh:lines() do
    for _, cp in utf8.codes(line) do
      t[cp] = true
    end
  end
  fh:close()
  return t
end

local function should_filter_candidate(cand)
  -- 仅过滤 table 翻译器候选，避免影响标点/符号等非词库输出
  -- 注意：开启 translator/enable_completion 后，候选类型会出现 completion；
  -- 若不纳入这里，会绕过 GB2312 过滤。
  return cand.type == "table"
      or cand.type == "user_table"
      or cand.type == "sentence"
      or cand.type == "completion"
end

function M.init(env)
  local cfg = env.engine.schema.config
  -- 用户目录（跨平台）
  local base = (rime_api and rime_api.get_user_data_dir()) or os.getenv("RIME") or os.getenv("HOME") or ""
  -- 路径来自 schema 配置
  local gb2312_rel = cfg:get_string("charset/files/gb2312") or "lua/charset/gb2312.txt"
  env.gb2312_path  = join(base, gb2312_rel)
  env.gb2312_map   = load_charset(env.gb2312_path) or {}

  -- 失败放行保护：若表为空，记录标志，后续直接放行
  env.fallback_pass = (next(env.gb2312_map) == nil)
end

function M.func(input, env)
  local ctx = env.engine.context

  -- 读取开关（兼容大小写）
  local use_gb2312 = ctx:get_option("GB2312") or ctx:get_option("gb2312")

  -- 失败放行：避免“全被拦”导致打不出字
  if env.fallback_pass then
    for cand in input:iter() do yield(cand) end
    return
  end

  -- 选择集合（GB2312 开=GB2312字符集，关=全集）
  local set = use_gb2312 and env.gb2312_map or nil

  for cand in input:iter() do
    if not set or not should_filter_candidate(cand) then
      yield(cand)  -- 全集：不过滤
    else
      local ok = true
      for _, cp in utf8.codes(cand.text) do
        if cp >= 0x80 and not set[cp] then
          ok = false; break
        end
      end
      if ok then yield(cand) end
    end
  end
end

return M
