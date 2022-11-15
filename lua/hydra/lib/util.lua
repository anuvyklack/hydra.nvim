local util = {}

---@param msg string
function util.warn(msg)
   vim.schedule(function()
      vim.notify_once('[Hydra] ' .. msg, vim.log.levels.WARN)
   end)
end

local id = 0

---Generate ID
---@return integer
function util.generate_id()
   id = id + 1
   return id
end

---Shortcut to `vim.api.nvim_replace_termcodes`.
---In the output of the `nvim_get_keymap` and `nvim_buf_get_keymap`
---functions some keycodes are replaced, for example: `<leader>` and
---some are not, like `<Tab>`.  So to avoid this incompatibility better
---to apply `termcodes` function on both `lhs` and the received keymap
---before comparison.
---@param keys string
---@return string
function util.termcodes(keys)
   return vim.api.nvim_replace_termcodes(keys, true, true, true)
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
   else
      error('[Hydra] Wrong color!')
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

---Return an empty table, in which any nested tables of any level will be
---created on fly when they will be accessed.
---Example:
---```
---    local t = util.unlimited_depth_table()
---    t[one][two][three] = 'text'
---```
--- you will get
---```
---    {
---       one = {
---          two = {
---             three = { 'text' }
---          }
---       }
---    }
---```
---but not an error.
function util.unlimited_depth_table()
   return setmetatable({}, mt)
end

---Like `vim.tbl_get` but returns the raw value (got with `rawget` function,
---ignoring  all metatables on the way). See `:help vim.tbl_get`
---@param tbl table | nil
---@param ... any keys
---@return any
function util.tbl_rawget(tbl, ...)
   if tbl == nil then return nil end

   local len = select('#', ...)
   local index = ... -- the first argument of the sequence `...`
   local result = rawget(tbl, index)

   if len == 1 then
      return result
   else
      return util.tbl_rawget(result, select(2, ...))
   end
end

---Deep unset metatable for input table and all nested tables.
---@param tbl table
function util.deep_unsetmetatable(tbl)
   setmetatable(tbl, nil)
   for _, subtbl in pairs(tbl) do
      if type(subtbl) == 'table' then
         util.deep_unsetmetatable(subtbl)
      end
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

---@param text string
---@return string[]
function util.split_string(text)
   local r = {}
   local stop = 0
   while stop do
      _, stop = text:find('%s+%S+')
      if stop then
         r[#r+1] = text:sub(1, stop)
         text = text:sub(stop + 1)
      end
   end
   r[#r+1] = text
   return r
end

---Merge input config into default
---@param default hydra.Config
---@param input hydra.Config
---@return hydra.Config
function util.megre_config(default, input)
   if not default then
      return vim.deepcopy(input)
   end
   local r = vim.deepcopy(default)
   for key, value in pairs(input) do
      if type(value) == 'table' then
         r[key] = util.megre_config(r[key], value)
      else
         r[key] = input[key]
      end
   end
   return r
end

return util
