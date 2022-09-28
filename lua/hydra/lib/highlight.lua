local function get_hl(name)
   if vim.o.termguicolors then
      return vim.api.nvim_get_hl_by_name(name, true)
   else
      return vim.api.nvim_get_hl_by_name(name, false)
   end
end

local name, settings
for _, color in ipairs({ 'Red', 'Blue', 'Amaranth', 'Teal', 'Pink' }) do
   settings = vim.tbl_deep_extend('force',
      get_hl('StatusLine'),
      get_hl(string.format('Hydra%s', color))
   )
   name = string.format('HydraStatusLine%s', color)
   vim.api.nvim_set_hl(0, name, settings)
end
