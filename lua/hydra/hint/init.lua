local cmdline = require('hydra.hint.cmdline')
local window = require('hydra.hint.window')
local statusline = require('hydra.hint.statusline')

local HintAutoCmdline = cmdline.HintAutoCmdline
local HintManualCmdline = cmdline.HintManualCmdline

local HintAutoWindow = window.HintAutoWindow
local HintManualWindow = window.HintManualWindow

local HintStatusLine = statusline.HintStatusLine
local HintStatusLineMute = statusline.HintStatusLineMute

---@return hydra.Hint
local function make_hint(input)
   local config = input.config
   local hint = input.hint
   if config == false then
      return HintStatusLineMute(input)
   elseif hint and config.type == 'window' then
      return HintManualWindow(input)
   elseif hint then
      return HintManualCmdline(input)
   elseif config.type == 'cmdline' then
      return HintAutoCmdline(input)
   elseif config.type == 'statusline' then
      return HintStatusLine(input)
   elseif config.type == 'window' then
      return HintAutoWindow(input)
   end
   error('Wrong hint type')
end

return make_hint
