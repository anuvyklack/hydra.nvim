local cmdline = require('hydra.hint.cmdline')
local window = require('hydra.hint.window')
local statusline = require('hydra.hint.statusline')

local HintAutoCmdline = cmdline.HintAutoCmdline
local HintManualCmdline = cmdline.HintManualCmdline

local HintAutoWindow = window.HintAutoWindow
local HintManualWindow = window.HintManualWindow

local HintStatusLine = statusline.HintStatusLine
local HintStatusLineMute = statusline.HintStatusLineMute

---@param hydra Hydra
---@param config hydra.hint.Config | false
---@param hint? string
---@return hydra.Hint
local function make_hint(hydra, config, hint)
   if config == false then
      return HintStatusLineMute(hydra)
   elseif hint and config.type == 'window' then
      return HintManualWindow(hydra, hint)
   elseif hint then
      return HintManualCmdline(hydra, hint)
   elseif config.type == 'cmdline' then
      return HintAutoCmdline(hydra)
   elseif config.type == 'statusline' then
      return HintStatusLine(hydra)
   elseif config.type == 'window' then
      return HintAutoWindow(hydra)
   end
   error('Wrong hint type')
end

return make_hint
