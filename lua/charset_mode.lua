-- 严格字符集过滤（GB2312 / GBK / ALL）
-- 设计：
--  - 两个布尔开关：GB2312、GBK；GB2312优先，其次GBK；都关=全集
--  - 只对汉字做过滤（CJK统一表 + 扩A + 兼容表 + 扩B~F）；其他字符放行
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

-- 是否汉字（过滤仅作用于这些区段）
local function is_cjk(cp)
  return (cp >= 0x4E00 and cp <= 0x9FFF)    -- CJK Unified Ideographs
      or (cp >= 0x3400 and cp <= 0x4DBF)    -- CJK Ext-A
      or (cp >= 0xF900 and cp <= 0xFAFF)    -- CJK Compatibility Ideographs
      or (cp >= 0x20000 and cp <= 0x2FA1F)  -- CJK Ext-B..F（覆盖到 2FA1F）
end

function M.init(env)
  local cfg = env.engine.schema.config
  -- 用户目录（跨平台）
  local base = (rime_api and rime_api.get_user_data_dir()) or os.getenv("RIME") or os.getenv("HOME") or ""
  -- 路径来自 schema 配置
  local gb2312_rel = cfg:get_string("charset/files/gb2312") or "lua/charset/gb2312.txt"
  local gbk_rel    = cfg:get_string("charset/files/gbk")    or "lua/charset/gbk.txt"
  env.gb2312_path  = join(base, gb2312_rel)
  env.gbk_path     = join(base, gbk_rel)
  env.gb2312_map   = load_charset(env.gb2312_path) or {}
  env.gbk_map      = load_charset(env.gbk_path)    or {}

  -- 失败放行保护：若两表都是空，记录标志，后续直接放行
  env.fallback_pass = (next(env.gb2312_map) == nil and next(env.gbk_map) == nil)
end

function M.func(input, env)
  local ctx = env.engine.context

  -- 读取开关（兼容大小写 & extended_charset）
  local use_gb2312 = ctx:get_option("GB2312") or ctx:get_option("gb2312")
  local use_gbk    = ctx:get_option("GBK")    or ctx:get_option("gbk") or ctx:get_option("extended_charset")

  -- 失败放行：避免“全被拦”导致打不出字
  if env.fallback_pass then
    for cand in input:iter() do yield(cand) end
    return
  end

  -- 选择集合（优先 GB2312，其次 GBK；都不选=全集）
  local set = nil
  if use_gb2312 then
    set = env.gb2312_map
  elseif use_gbk then
    set = env.gbk_map
  end

  for cand in input:iter() do
    if not set then
      yield(cand)  -- 全集：不过滤
    else
      local ok = true
      for _, cp in utf8.codes(cand.text) do
        if is_cjk(cp) and not set[cp] then
          ok = false; break
        end
      end
      if ok then yield(cand) end
    end
  end
end

return M