---@param parent table?
---@return table
local function Class(parent)
   local class = {}
   class.__index = class
   -- class.Super = parent

   local meta_class = {}
   meta_class.__index = parent

   function meta_class:__call(...)
      local obj = setmetatable({}, class)
      if type(class._constructor ) == 'function' then
         return obj, obj:_constructor(...)
      else
         return obj
      end
   end

   return setmetatable(class, meta_class)
end

return Class
