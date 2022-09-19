---@param parent table?
---@return table
local function class(parent)
   local class = {}
   class.__index = class
   -- class.Super = parent

   local meta_class = {}
   meta_class.__index = parent

   function meta_class:__call(...)
      local obj = setmetatable({}, class)
      if type(class.initialize ) == 'function' then
         return obj, obj:initialize(...)
      else
         return obj
      end
   end

   return setmetatable(class, meta_class)
end

return class
