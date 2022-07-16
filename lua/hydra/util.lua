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

---Shortcut to `vim.api.nvim_replace_termcodes`
---
---In the output of the `nvim_get_keymap` and `nvim_buf_get_keymap`
---functions some keycodes are replaced, for example: `<leader>` and
---some are not, like `<Tab>`.  So to avoid this incompatibility better
---to apply `termcodes` function on both `lhs` and the received keymap
---before comparison.
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

---Like `vim.tbl_get` but returns the raw value (got with `rawget` function,
---ignoring  all metatables on the way).
---@param tbl table | nil
---@param ... any keys
---@return any
---@see :help vim.tbl_get
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
   for _, subtbl in pairs(tbl) do
      setmetatable(tbl, nil)
      if type(subtbl) == 'table' then
         util.deep_unsetmetatable(subtbl)
      end
   end
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

-- ---Wraps a passed keymap into a function, on call of which the keymap content
-- ---will be executed.
-- ---@param rhs string | function
-- ---@param opts KeymapOpts
-- ---@return function
-- function util.get_keymap_function(rhs, opts)
--    return function()
--       ---@type string
--       local keys, mode
--       if opts.expr then
--          if type(rhs) == 'function' then
--             keys = rhs()
--          elseif type(rhs) == 'string' then
--             keys = vim.api.nvim_eval(rhs)
--          end
--       elseif type(rhs) == 'function' then
--          rhs()
--          return
--       elseif type(rhs) == 'string' then
--          keys = rhs
--       end
--       keys = util.termcodes(keys)
--       mode = opts.remap and 'im' or 'in'
--       vim.api.nvim_feedkeys(keys, mode, true)
--    end
-- end

return util
