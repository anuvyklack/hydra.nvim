local util = {}
local id = 0

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
   return vim.api.nvim_replace_termcodes(keys, true, true, true)
end

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

---Return table where all `key`, `value` pairs are reversed.
---```
---    table[key] = value  =>  table[value] = key
---```
---@param tbl table
---@return table
function util.reverse_tbl(tbl)
   local r = {}
   for key, value in pairs(tbl) do
      r[value] = key
   end
   return r
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

function util.make_meta_accessor(get, set)
   return setmetatable({}, {
      __index = not get and nil or function(_, k) return get(k) end,
      __newindex = not set and nil or function(_, k, v) return set(k, v) end
   })
end

function util.disable_meta_accessor(accessor)
   local function disable()
      util.warn(string.format(
         '"vim.%s" meta-accessor is disabled inside config.on_exit() function',
         accessor))
   end
   return util.make_meta_accessor(disable, disable)
end

function util.warn(msg)
   vim.schedule(function()
      vim.notify_once('[Hydra] '..msg, vim.log.levels.WARN)
   end)
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

return util
