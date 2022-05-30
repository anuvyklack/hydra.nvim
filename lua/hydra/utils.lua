local utils = {}
local id = 0

---Generate ID
---@return integer
function utils.generate_id()
   id = id + 1
   return id
end

function utils.get_color_from_config(foreign_keys, exit)
   if foreign_keys == 'run' then
      return 'pink'
   elseif foreign_keys == 'warn' and exit then
      return 'teal'
   elseif foreign_keys == 'warn' then
      return 'amaranth'
   elseif exit then
      return 'blue'
   else
      return 'red'
   end
end

function utils.get_config_from_color(color)
   if color == 'pink' then
      return 'run', false
   elseif color == 'teal' then
      return 'warn', true
   elseif color == 'amaranth' then
      return 'warn', false
   elseif color == 'blue' then
      return nil, true
   elseif color == 'red' then
      return nil, false
   end
end

return utils
