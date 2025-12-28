-- lua/date_translator.lua
-- 提供系统变量：date, time, week
-- 仅支持关键词："date"、"time"、"week"（保持简单、可回滚）

local weekday_cn = {"日","一","二","三","四","五","六"}

function date_translator(input, seg)
  -- 仅当整词输入时触发（ascii_segmentor 会将完整 ASCII 单词当作一个 segment 传入）
  if input == "datetime" then
    -- 兼容性保留（不主动使用），但按你要求不公开该关键字（我们不会为其注册短码）
    yield(Candidate("date", seg.start, seg._end, os.date("%Y-%m-%d %H:%M:%S"), ""))
    yield(Candidate("date", seg.start, seg._end, os.date("%Y/%m/%d %H:%M:%S"), ""))
    return
  end

  if input == "date" then
    -- 用户要求：第一候选为 YYYY年MM月DD日
    yield(Candidate("date", seg.start, seg._end, os.date("%Y年%m月%d日"), ""))
    yield(Candidate("date", seg.start, seg._end, os.date("%Y-%m-%d"), ""))
    yield(Candidate("date", seg.start, seg._end, os.date("%Y.%m.%d"), ""))

    -- 附加：当天农历（最后一位候选），并标注节日或节气（如果有）
    local ok, lunar = pcall(function()
      local lunar_mod = require("lunarDate")
      local jq_mod = require("lunarJq")
      local gdate = os.date("%Y%m%d")
      local info = lunar_mod.Date2LunarInfo(gdate)
      if not info then return nil end
      local lunar_text = info.year .. " " .. info.monthName .. " " .. info.dayName
      -- 简单节日表（常见节日）
      local festival_map = {
        ["1-1"] = "春节", ["1-15"] = "元宵", ["5-5"] = "端午", ["8-15"] = "中秋", ["7-7"] = "七夕", ["12-8"] = "腊八"
      }
      local key = tostring(info.monthNum) .. "-" .. tostring(info.dayNum)
      local special = festival_map[key] or ""
      -- 节气检测：调用 jq_mod.JQtest
      local jqname = ""
      if jq_mod and type(jq_mod.JQtest) == "function" then
        local jqres = jq_mod.JQtest(gdate) or ""
        if jqres ~= "" then jqname = string.gsub(jqres, "^-", "") end
      end
      if jqname ~= "" then
        if special ~= "" then special = special .. "、" .. jqname else special = jqname end
      end
      if special ~= "" then lunar_text = lunar_text .. "（" .. special .. "）" end
      return lunar_text
    end)
    if ok and lunar then
      yield(Candidate("date", seg.start, seg._end, lunar, "农历"))
    end

    return
  end

  if input == "time" then
    yield(Candidate("time", seg.start, seg._end, os.date("%H:%M"), ""))
    yield(Candidate("time", seg.start, seg._end, os.date("%H:%M:%S"), ""))
    return
  end

  if input == "week" then
    local w = tonumber(os.date("%w")) or 0 -- 0(Sun)-6
    local cn = weekday_cn[w+1]
    -- 星期X / 周X
    yield(Candidate("week", seg.start, seg._end, "星期"..cn, ""))
    yield(Candidate("week", seg.start, seg._end, "周"..cn, ""))
    -- 当年的第几周：使用 %W（以周一为周首），从 0 起算，+1 以 1 为起点
    local wn = (tonumber(os.date("%W")) or 0) + 1
    yield(Candidate("week", seg.start, seg._end, tostring(wn) .. "周", "第"..tostring(wn).."周"))
    return
  end
end
