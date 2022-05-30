--[[

-- enter hydra
keymap.set(body..head, table.concat{
   <Plug>(hydra_pre),
   <Plug>(hydra_head),
   <Plug>(hydra_show_hint),
   <Plug>(hydra_wait)
})

keymap.set(<Plug>(hydra_wait)head, table.concat{
   <Plug>(hydra_head),
   <Plug>(hydra_show_hint),
   <Plug>(hydra_wait)
})

keymap.set(<Plug>(hydra_wait){the first N keys in head}, <Plug>(hydra_leave)))
keymap.set(<Plug>(hydra_wait), <Plug>(hydra_leave)))

keymap.set(<Plug>(hydra_wait), <Plug>(hydra_leave))

--]]

local utils = require('hydra/utils')
local default_config = {
   pre  = nil, -- before entering hydra
   post = nil, -- after leaving hydra
   timeout = false, -- true, false or number in milliseconds
   exit = false,
   foreign_keys = nil, -- nil | warn | run
   color = 'red',
}
local active_hydra


---@class Hydra
---@field name string
---@field id number
---@field config table
---@field mode string
---@field body string
---@field heads table<string, string|function|table>
---@field plug table<string, string>
---@field _show_hint function
local Hydra = {}
Hydra.__index = Hydra
setmetatable(Hydra, {
   ---The `new` method which created a new object and call constructor for it.
   ---@param ... unknown everything that constructor accepts
   ---@return Hydra
   __call = function(_, ...)
      local obj = setmetatable({}, Hydra)
      obj:_constructor(...)
      return obj
   end
})

---Constructor
---@param input table
---@return Hydra
function Hydra:_constructor(input)
   vim.validate({
      name = { input.name, 'string' },
      config = { input.config, 'table', true },
      mode = { input.mode, 'string' },
      body = { input.body, 'string' },
      heads = { input.heads, 'table' },
      exit = { input.exit, { 'string', 'table' }, true }
   })
   vim.validate({
      pre = { input.config.pre, 'function', true },
      post = { input.config.post, 'function', true },
      exit = { input.config.exit, 'boolean', true },
      timeout = { input.config.timeout, { 'boolean', 'number' }, true }
   })
   vim.validate({
      foreign_keys = { input.config.foreign_keys, function(foreign_keys)
         if type(foreign_keys) == 'nil'
            or foreign_keys == 'warn' or foreign_keys == 'run'
         then
            return true
         else
            return false
         end
      end, 'Hydra: config.foreign_keys value could be either "warn" or "run"' }
   })
   vim.validate({
      color = { input.config.color, function (color)
         local valid_colors = { red = true, blue = true, amaranth = true, teal = true, pink = true }
         return valid_colors[color] or false
      end, 'Hydra: color value could be one of: red, blue, amaranth, teal, pink' }
   })

   self.id = utils.generate_id() -- Unique ID for each Hydra.
   self.name = input.name
   self.config = vim.tbl_deep_extend('keep', input.config, default_config)
   self.mode = input.mode
   self.body = input.body
   self.exit = type(input.exit) == "string" and { input.exit } or input.exit or { '<Esc>' }

   -- Bring 'foreign_keys', 'exit' and 'color' options into line.
   local color = utils.get_color_from_config(self.config.foreign_keys, self.config.exit)
   if color ~= 'red' and color ~= self.config.color then
      self.config.color = color
   elseif color ~= self.config.color then
      self.config.foreign_keys, self.config.exit =
         utils.get_config_from_color(self.config.color)
   end

   self.heads = input.heads
   for head, map in pairs(self.heads) do
      vim.validate({
         head = { map, function(mapping)
            if type(mapping) == 'string' or type(mapping) == 'function' then
               return true
            elseif type(mapping) == 'table'
               and (type(mapping[1]) == 'string' or type(mapping[1]) == 'function')
               and type(mapping[2]) == 'table'
            then
               return true
            else
               return false
            end
         end, 'Hydra: wrong head type'}
      })
      if type(map) == 'string' or type(map) == 'function' then
         self.heads[head] = { map, {} }
      end
   end

   self.original_options = {}

   -- Table with all left hand sides of key mappings of the type `<Plug>...`.
   self.plug = setmetatable({}, {
      __index = function (t, key)
         t[key] = ('<Plug>(hydra_%s_%s)'):format(self.id, key)
         return t[key]
      end
   })

   self:set_keymap(self.plug.pre, function() self:_pre() end)
   self:set_keymap(self.plug.post, function() self:_post() end)
   self:set_keymap(self.plug.show_hint, function() self:_show_hint() end)

   local hint = { ('echon "%s: '):format(self.name) }
   for head, map in pairs(self.heads) do
      -- Define <Plug> mappings for hydra heads actions.
      self:set_keymap(self.plug[head], unpack(map))
      do
         local desc = map[2].desc and string.format(': %s, ', map[2].desc) or ', '
         if map[2].exit then
            color = utils.get_color_from_config(self.config.foreign_keys, map[2].exit)
         else
            color = self.config.color
         end
         color = color:gsub("^%l", string.upper) -- amaranth -> Amaranth
         hint[#hint+1] = ('echohl Hydra%s'):format(color)
         hint[#hint+1] = ('echon "%s"'):format(head)
         hint[#hint+1] = 'echohl None'
         hint[#hint+1] = ('echon "%s"'):format(desc)
      end
   end
   for i, key in ipairs(self.exit) do
      hint[#hint+1] = 'echohl HydraBlue'
      hint[#hint+1] = ('echon "%s"'):format(key)
      hint[#hint+1] = 'echohl None'
      hint[#hint+1] = ('echon ": exit%s"'):format(i < #self.exit and ', ' or '')
   end

   -- self:set_keymap(self.plug.wait, self.plug.leave)

   hint = table.concat(hint, ' | ')
   function self:_show_hint()
      vim.cmd(hint)
   end
end

function Hydra:_pre()
   active_hydra = self
   self.original_options.showcmd  = vim.o.showcmd
   self.original_options.showmode = vim.o.showmode
   vim.o.showcmd = true
   vim.o.showmode = false

   self.original_options.timeout  = vim.o.timeout
   self.original_options.ttimeout = vim.o.ttimeout
   vim.o.ttimeout = not self.original_options.timeout and true
                    or self.original_options.ttimeout
   if self.config.timeout then
      vim.o.timeout = true
      if type(self.config.timeout) == "number" then
         self.original_options.timeoutlen = vim.o.timeoutlen
         vim.o.timeoutlen = self.config.timeout
      end
   else
      vim.o.timeout = false
   end

   if self.config.pre then self.config.pre() end

   if vim.fn.exists('HydraRestoreOptions') > 0 then
      vim.cmd 'HydraRestoreOptions'
   end
   -- Make an Ex command to restore options overridden by Hydra if it was
   -- emergency leaved with <C-c>.
   vim.api.nvim_create_user_command('HydraRestoreOptions', function() self:_post() end, {})
end

function Hydra:_post()
   for option, value in pairs(self.original_options) do
      vim.o[option] = value
   end
   if self.config.post then self.config.post() end
   vim.api.nvim_del_user_command('HydraRestoreOptions')
   active_hydra = nil
end

function Hydra:_leaving()
   if self.config.color == 'pink' then
      vim.fn.getchar()
   elseif self.config.color == 'amaranth' then
      print 'An Amaranth Hydra can only exit through a blue head'
      if vim.fn.getchar(1) ~= 0 then
         vim.fn.getchar()
      end
   end
end

-- function Hydra:_blue_head()
-- end

function Hydra:set_keymap(...)
   vim.keymap.set(self.mode, ...)
end

function Hydra:define_entering_mapping()

   for head, map in pairs(self.heads) do
      self:set_keymap(self.body..head, table.concat(
         self.plug.pre,
         self.plug[head]
      ))
   end

end

---Restore options overridden by Hydra if it was emergency leaved with <C-c>.
local function restore_original_options()
   if active_hydra then
      active_hydra:_post()
   end
end

-------------------------------------------------------------------------------
local sample_hydra = Hydra({
   name = 'Side scroll',
   config = {
      pre  = function() end, -- before entering hydra
      post = function() end, -- after leaving hydra
      timeout = false, -- false or num in milliseconds
      exit = false,
      foreign_keys = nil, -- nil | 'warn' | 'run'
      color = 'blue',
   },
   mode = 'n',
   body = 'z',
   heads = {
      l = 'zl',
      h = { 'zh', { desc = 'description' } },
      H = { 'zH', { desc = 'description', exit = true } }
   },
   exit = { '<Esc>', 'q' },
})
print(sample_hydra)
-------------------------------------------------------------------------------


return Hydra, restore_original_options
