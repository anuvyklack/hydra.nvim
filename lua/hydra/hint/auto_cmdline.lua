local Class = require('hydra.class')
local Hint = require('hydra.hint.hint')
local util = require('hydra.util')
local strdisplaywidth = vim.fn.strdisplaywidth

---@class hydra.hint.AutoCmdline : hydra.Hint
local HintAutoCmdline = Class(Hint)

---@param hydra Hydra
function HintAutoCmdline:_constructor(hydra)
   Hint._constructor(self, hydra)
   self.o = hydra.options.o
   self.height = 1
end

function HintAutoCmdline:_make_message()
   ---Available screen width for echo message
   ---@type number
   local space = vim.v.echospace - 1
   local hint = { {' '} }
   local continue = true

   if self.config.show_name then
      hint[#hint+1] = { (self.hydra_name or 'HYDRA')..': ' }
      space = space - strdisplaywidth(hint[#hint][1])
   end

   local heads = self:_swap_head_with_index()
   for _, head_spec in ipairs(heads) do
      continue, space = self:_add_chunk(hint, space, { head_spec.head, 'Hydra'..head_spec.color })
      if not continue then break end

      local desc = head_spec.desc
      if desc then
         desc = string.format(': %s, ', desc)
      else
         desc = ', '
      end
      continue, space = self:_add_chunk(hint, space, { desc })
      if not continue then break end
   end
   hint[#hint][1] = hint[#hint][1]:gsub(', $', '')

   self.message = hint
end

---@param msg table<integer, string[]>
---@param space number
---@param chunk string[]
---@return boolean continue Can we continue after adding this chunk?
---@return number space Available echo space after adding chunk
function HintAutoCmdline:_add_chunk(msg, space, chunk)
   local new_space = space - strdisplaywidth(chunk[1])
   if new_space > 0 then
      msg[#msg+1] = chunk
      return true, new_space
   else
      local text, hl = chunk[1], chunk[2]
      text = util.split_string(text)
      local new_text = {}
      local len
      for _, word in ipairs(text) do
         len = strdisplaywidth(word)
         if len < space then
            table.insert(new_text, word)
            space = space - len
         elseif space > 3 then
            table.insert(new_text, '...')
            space = space - 3
            break
         else
            break
         end
      end
      new_text = table.concat(new_text)
      msg[#msg+1] = { new_text, hl }
      return false, space
   end
end

function HintAutoCmdline:show()
   -- 'shortmess' 'shm'	string	(Vim default "filnxtToOF", Vi default: "S")
   if not self.message then self:_make_message() end
   if self.o.cmdheight < self.height then
      self.o.cmdheight = self.height
   end
   vim.cmd 'redraw'
   vim.api.nvim_echo(self.message, false, {})
end

HintAutoCmdline.update = HintAutoCmdline.show

function HintAutoCmdline:leave()
   local line
   if self.hydra_color == 'amaranth' then
      -- 'An Amaranth Hydra can only exit through a blue head'
      line = {
         {'\n'}, {' An '},
         {'Amaranth', 'HydraAmaranth'},
         {' Hydra can only exit through a blue head'}
      }
   elseif self.hydra_color == 'teal' then
      -- 'A Teal Hydra can only exit through one of its heads'
      line = {
         {'\n'}, {' A '},
         {'Teal', 'HydraTeal'},
         {' Hydra can only exit through one of its heads'}
      }
   end

   local message = vim.deepcopy(self.message)
   vim.list_extend(message, line)

   self.o.cmdheight = self.height + 1
   vim.cmd 'redraw'
   vim.api.nvim_echo(message, false, {})
end

return HintAutoCmdline
