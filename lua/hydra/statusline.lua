local statusline = {}

---Returns `true` if there is an active hydra
---@return boolean
function statusline.is_active()
   return _G.Hydra and true or false
end

---Get the name of an active Hydra if it has it
---@return string | nil
function statusline.get_name()
   return _G.Hydra and _G.Hydra.name
end

---Get an active Hydra's statusline hint if it provides it
---@return string | nil
function statusline.get_hint()
   if _G.Hydra and _G.Hydra.hint.get_statusline then
      return _G.Hydra.hint:get_statusline()
   end
end

---Get the color of an active Hydra
---@return string
function statusline.get_color()
   return _G.Hydra and string.lower(_G.Hydra.config.color)
end

return statusline
