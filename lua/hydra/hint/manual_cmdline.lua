local Class = require('hydra.class')
local HintAutoCmdline = require('hydra.hint.auto_cmdline')
local vim_options = require('hydra.hint.vim_options')

---@class hydra.hint.ManualCmdline : hydra.hint.AutoCmdline
---@field hint string[]
---@field height integer
---@field need_to_update boolean
local HintManualCmdline = Class(HintAutoCmdline)

---@param hydra Hydra
---@param hint string
function HintManualCmdline:_constructor(hydra, hint)
   HintAutoCmdline._constructor(self, hydra)
   self.need_to_update = false

   self.config.funcs = setmetatable(self.config.funcs or {}, {
      __index = vim_options
   })

   self.hint = vim.split(hint, '\n')
   -- Remove last empty string.
   if self.hint and self.hint[#self.hint] == '' then
      self.hint[#self.hint] = nil
   end
end

function HintManualCmdline:_make_message()
   ---@type string[]
   local hint = vim.deepcopy(self.hint)

   ---@type table<string, hydra.HeadSpec>
   local heads = vim.deepcopy(self.heads)

   self.message = {}

   local space, chunks, continue
   for _, line in ipairs(hint) do
      ---Available screen width for echo message
      ---@type number
      space = vim.v.echospace
      chunks = {}

      line = line:gsub('%^', '')

      local start, stop, found = 0, 0, nil
      while start do
         start, stop, found = line:find('%%{(.-)}', 1)
         ---@cast found string
         if start then
            self.need_to_update = true

            local fun = self.config.funcs[found]
            if not fun then
               error(string.format('[Hydra] "%s" not present in "config.hint.functions" table', found))
            end

            line = table.concat({
               line:sub(1, start - 1),
               fun(),
               line:sub(stop + 1)
            })
         end
      end

      start, stop, found = 0, 0, nil
      while start do
         start, stop, found = line:find('_(.-)_', stop + 1)
         ---@cast found string
         if found and vim.startswith(found, [[\]]) then found = found:sub(2) end
         if start then
            if not heads[found] then
               error(string.format('[Hydra] docsting error, head "%s" does not exist', found))
            end
            local color = heads[found].color

            table.insert(chunks, { line:sub(1, start-1) })
            table.insert(chunks, { found, 'Hydra'..color })

            line = line:sub(stop+1)
            heads[found] = nil
            start, stop = 0, 0
         end
      end
      table.insert(chunks, { line })

      for _, chunk in ipairs(chunks) do
         continue, space = self:_add_chunk(self.message, space, chunk)
         if not continue then
            break
         end
      end

      table.insert(self.message, {'\n'})
   end

   -- Remove heads with `desc = false`.
   for head, properties in pairs(heads) do
      if properties.desc == false then
         heads[head] = nil
      end
   end

   if vim.tbl_isempty(heads) then
      table.remove(self.message) -- remove last '\n' symbol
      self.height = #hint
   else -- There are remain hydra heads, that not present in manually created hint.
      table.insert(self.message, {' '})

      ---@type string[]
      local heads_lhs = vim.tbl_keys(heads)
      table.sort(heads_lhs, function (a, b)
         return heads[a].index < heads[b].index
      end)

      local line = {}
      for _, head in pairs(heads_lhs) do
         local head_spec = self.heads[head]
         continue, space = self:_add_chunk(line, space, { head_spec.head, 'Hydra'..head_spec.color })
         if not continue then break end

         local desc = head_spec.desc
         if desc then
            desc = string.format(': %s, ', desc)
         else
            desc = ', '
         end
         continue, space = self:_add_chunk(line, space, { desc })
         if not continue then break end
      end
      line[#line][1] = line[#line][1]:gsub(', $', '')
      vim.list_extend(self.message, line)
      self.height = #hint + 1
   end

   self:debug(self.message)
end

return HintManualCmdline
