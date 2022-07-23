local HintAutoCmdline = require('hydra.hint.auto_cmdline')
local HintManualCmdline = require('hydra.hint.manual_cmdline')
local HintManualWindow = require('hydra.hint.manual_window')
local HintAutoWindow = require('hydra.hint.auto_window')
local HintStatusLine, HintStatusLineMute = unpack(require('hydra.hint.statusline'))

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
   error('wrong hint type')
end

return make_hint
