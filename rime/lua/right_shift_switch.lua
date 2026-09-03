-- 右 Shift 中英文切换：
-- - 单击右 Shift：切换中英文
-- - 按住右 Shift 再按其他键：只作为上档键，不切换
--
-- Rime 自带 ascii_composer/switch_key 对 Shift 的处理不够细，
-- 在某些版本/平台上会让 Shift+标点误触发中英文切换。
-- 这里用 Lua 明确区分“单击”和“组合键”。

local M = {}

local Accepted = 1
local Noop = 2

function M.init(env)
  env.right_shift_code = KeyEvent("Shift_R").keycode
  env.right_shift_down = false
  env.right_shift_used_as_modifier = false
end

local function toggle_ascii_mode(env)
  local ctx = env.engine.context

  -- 对齐 Rime 的 commit_code 手感：有未完成编码时，先上屏再切换。
  if ctx:is_composing() then
    if type(ctx.clear_non_confirmed_composition) == "function" then
      pcall(function() ctx:clear_non_confirmed_composition() end)
    end
    ctx:commit()
  end

  ctx:set_option("ascii_mode", not ctx:get_option("ascii_mode"))
end

function M.func(key, env)
  local is_right_shift = key.keycode == env.right_shift_code

  if is_right_shift then
    if key:release() then
      local should_toggle = env.right_shift_down and not env.right_shift_used_as_modifier
      env.right_shift_down = false
      env.right_shift_used_as_modifier = false

      if should_toggle then
        toggle_ascii_mode(env)
        return Accepted
      end

      return Noop
    end

    env.right_shift_down = true
    env.right_shift_used_as_modifier = false
    return Noop
  end

  if env.right_shift_down and not key:release() then
    env.right_shift_used_as_modifier = true
  end

  return Noop
end

return M
