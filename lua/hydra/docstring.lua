-- vim.api.nvim_set_hl(0, 'HydraInfoWindow', { link = 'Statusline' })
vim.api.nvim_set_hl(0, 'HydraInfoWindow', { link = 'NormalFloat' })

vim.api.nvim_set_hl(0, 'HydraRed',     { fg = '#f2594b', bold = true, default = true })
vim.api.nvim_set_hl(0, 'HydraBlue',    { fg = '#0091f7', bold = true, default = true })
vim.api.nvim_set_hl(0, 'HydraAmarant', { fg = '#FF355E', bold = true, default = true })
vim.api.nvim_set_hl(0, 'HydraTeal',    { fg = '#009090', bold = true, default = true })
vim.api.nvim_set_hl(0, 'HydraPink',    { fg = '#f766ad', bold = true, default = true })


-- nvim_buf_add_highlight
-- vim.highlight.range
-- nvim_buf_set_extmark

-- ^ - is an empty symbol. It won't be rendered.
local docstring = [[
 ^^Mark^            ^^Unmark^           ^Actions^          ^Search
^^^^^^^^^^------------------------------------------------------------------
 ^_m_: mark         ^_u_: unmark        _x_: execute       _R_: re-isearch
 ^_s_: save         ^_U_: unmark up     _b_: bury          _I_: isearch
 ^_d_: delete       ^^ ^                _g_: refresh       _O_: multi-occur
 ^_D_: delete up    ^^ ^                _T_: files only
 _\^_: modified     _\__: modified
]]

-- hint = hint:gsub([[%^]], '')
docstring = vim.split(docstring, '\n')
docstring[#docstring] = nil

local longest_line
local max_line_len = 0
for i, line in ipairs(docstring) do
   local line_len = vim.fn.strdisplaywidth(line)
   if line_len > max_line_len then
      max_line_len = line_len
      longest_line = i
   end
end

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, docstring)
vim.bo[bufnr].filetype = 'hydra_docstring'
vim.bo[bufnr].modifiable = false
vim.bo[bufnr].readonly = true

local visible_width = max_line_len
local i = 0
while(true) do
   i = docstring[longest_line]:find('[_^]', i + 1)
   if i then
      visible_width = visible_width - 1
   else
      break
   end
end

local width = visible_width
local height = #docstring

-- print(visible_width, max_line_len)

local winid = vim.api.nvim_open_win(bufnr, false, {
   relative = 'editor',
   anchor = 'SW',
   row = vim.o.lines - 2,
   col = math.floor((vim.o.columns - width) / 2),
   width = width,
   height = height,
   style = 'minimal',
   focusable = false,
   noautocmd = true
})
vim.wo[winid].winhighlight = 'NormalFloat:HydraInfoWindow'
vim.wo[winid].conceallevel = 3
vim.wo[winid].foldenable = false
vim.wo[winid].signcolumn = 'no'


-- vim.api.nvim_win_close(winid, false)
-- vim.api.nvim_buf_delete(bufnr, { force = true, unload = false })
