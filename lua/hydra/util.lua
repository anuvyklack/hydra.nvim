local util = {}
local id = 0

---@param msg string
function util.warn(msg)
   vim.schedule(function()
      vim.notify_once('[Hydra] ' .. msg, vim.log.levels.WARN)
   end)
end

---Generate ID
---@return integer
function util.generate_id()
   id = id + 1
   return id
end

---Shortcut to `vim.api.nvim_replace_termcodes`
---@param keys string
---@return string
function util.termcodes(keys)
   return vim.api.nvim_replace_termcodes(keys, true, true, true) --[[@as string]]
end

---@param foreign_keys hydra.foreign_keys
---@param exit boolean
---@return hydra.color color
function util.get_color_from_config(foreign_keys, exit)
   if foreign_keys == 'run' then
      if exit then
         return 'blue'
      else
         return 'pink'
      end
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

---@param color hydra.color
---@return hydra.foreign_keys foreign_keys
---@return boolean exit
function util.get_config_from_color(color)
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

---Deep unset metatables for input table all nested tables.
---@param tbl table
function util.deep_unsetmetatable(tbl)
   for _, subtbl in pairs(tbl) do
      setmetatable(tbl, nil)
      if type(subtbl) == 'table' then
         util.deep_unsetmetatable(subtbl)
      end
   end
end

-- Recursive subtables
local mt = {}
function mt.__index(self, subtbl)
   self[subtbl] = setmetatable({}, {
      __index = mt.__index
   })
   return self[subtbl]
end

function util.unlimited_depth_table()
   return setmetatable({}, mt)
end

---@param get function
---@param set function
---@return MetaAccessor
function util.make_meta_accessor(get, set)
   return setmetatable({}, {
      __index = not get and nil or function(_, k) return get(k) end,
      __newindex = not set and nil or function(_, k, v) return set(k, v) end
   })
end

---@param accessor_name string
---@return MetaAccessor
function util.disable_meta_accessor(accessor_name)
   local function disable()
      util.warn(string.format(
         '"vim.%s" meta-accessor is disabled inside config.on_exit() function',
         accessor_name))
   end

   return util.make_meta_accessor(disable, disable)
end

---Create once callback
---@param callback function
---@return function
function util.once(callback)
   local done = false
   return function(...)
      if done then return end
      done = true
      callback(...)
   end
end

---@param func? function
---@param new_fn function
---@return function
function util.add_hook_before(func, new_fn)
   if func then
      return function(...)
         new_fn(...)
         return func(...)
      end
   else
      return new_fn
   end
end

return util
