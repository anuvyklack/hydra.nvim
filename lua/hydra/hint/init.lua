local HintManualWindow = require('hydra.hint.manual')
local HintAutoWindow = require('hydra.hint.auto')
local HintStatusLine, HintStatusLineMute = unpack(require('hydra.hint.statusline'))

---@param hydra Hydra
---@param config table | 'statusline' | false
---@param hint? string[]
---@return hydra.Hint
local function make_hint(hydra, config, hint)
   if hint then
      return HintManualWindow(hydra, hint)
   elseif config == 'statusline' then
      return HintStatusLine(hydra)
   elseif config == false then
      return HintStatusLineMute(hydra)
   else
      return HintAutoWindow(hydra)
   end
end

return make_hint
