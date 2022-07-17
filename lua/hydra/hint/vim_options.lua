local M = {}

M.number = function()
   if vim.o.number then
      return '[x]'
   else
      return '[ ]'
   end
end
M.nu = M.number

M.relativenumber = function()
   if vim.o.relativenumber then
      return '[x]'
   else
      return '[ ]'
   end
end
M.rnu = M.relativenumber

M.virtualedit = function()
   if vim.tbl_contains(vim.opt.virtualedit:get(), 'all') then
      return '[x]'
   else
      return '[ ]'
   end
end
M.ve = M.virtualedit

M.list = function()
   if vim.o.list then
      return '[x]'
   else
      return '[ ]'
   end
end

M.spell = function()
   if vim.o.spell then
      return '[x]'
   else
      return '[ ]'
   end
end

M.wrap = function()
   if vim.o.wrap then
      return '[x]'
   else
      return '[ ]'
   end
end

M.cursorline = function()
   if vim.o.cursorline then
      return '[x]'
   else
      return '[ ]'
   end
end
M.cul = M.cursorline

M.cursorcolumn = function()
   if vim.o.cursorcolumn then
      return '[x]'
   else
      return '[ ]'
   end
end
M.cuc = M.cursorcolumn

M.cux = function()
   if vim.o.cursorline and vim.o.cursorcolumn then
      return '[x]'
   else
      return '[ ]'
   end
end

return M

