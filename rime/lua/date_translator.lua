-- Dynamic special codes for lightWubi86.
--
-- Special codes:
--   date - current date
--   time - current time
--   week - current weekday

local M = {}

local WEEKDAY_CN = { "日", "一", "二", "三", "四", "五", "六" }
local DIGITS_CN = {
  ["0"] = "〇",
  ["1"] = "一",
  ["2"] = "二",
  ["3"] = "三",
  ["4"] = "四",
  ["5"] = "五",
  ["6"] = "六",
  ["7"] = "七",
  ["8"] = "八",
  ["9"] = "九",
}

local function number_cn(n)
  n = tonumber(n) or 0
  if n < 10 then
    return DIGITS_CN[tostring(n)]
  end
  if n == 10 then
    return "十"
  end
  if n < 20 then
    return "十" .. DIGITS_CN[tostring(n % 10)]
  end

  local ten = math.floor(n / 10)
  local one = n % 10
  if one == 0 then
    return DIGITS_CN[tostring(ten)] .. "十"
  end
  return DIGITS_CN[tostring(ten)] .. "十" .. DIGITS_CN[tostring(one)]
end

local function year_cn(year)
  local result = {}
  for digit in tostring(year):gmatch(".") do
    table.insert(result, DIGITS_CN[digit] or digit)
  end
  return table.concat(result, "")
end

local function candidate(seg, text, comment)
  yield(Candidate("date", seg.start, seg._end, text, comment or ""))
end

function M.func(input, seg)
  if input == "date" then
    local year = tonumber(os.date("%Y"))
    local month = tonumber(os.date("%m"))
    local day = tonumber(os.date("%d"))

    candidate(seg, string.format("%d年%d月%d日", year, month, day))
    candidate(seg, year_cn(year) .. "年" .. number_cn(month) .. "月" .. number_cn(day) .. "日")
    candidate(seg, os.date("%Y-%m-%d"))
    return
  end

  if input == "time" then
    local hour = tonumber(os.date("%H"))
    local minute = tonumber(os.date("%M"))

    candidate(seg, string.format("%d时%d分", hour, minute))
    candidate(seg, number_cn(hour) .. "时" .. number_cn(minute) .. "分")
    candidate(seg, os.date("%H:%M:%S"))
    return
  end

  if input == "week" then
    local weekday = tonumber(os.date("%w")) or 0
    candidate(seg, "星期" .. WEEKDAY_CN[weekday + 1])
    return
  end
end

return M
