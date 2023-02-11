local api = vim.api

local function get_hl(name)
   ---@type boolean
   local rgb = api.nvim_get_option('termguicolors')
   local result = {}
   for key, value in pairs(api.nvim_get_hl_by_name(name, rgb)) do
      if type(key) == 'string' then
         result[key] = value
      end
   end
   return result
end

local name, settings
for _, color in ipairs({ 'Red', 'Blue', 'Amaranth', 'Teal', 'Pink' }) do
   settings = vim.tbl_deep_extend('force',
      get_hl('StatusLine'),
      get_hl(string.format('Hydra%s', color))
   )
   name = string.format('HydraStatusLine%s', color)
   api.nvim_set_hl(0, name, settings)
end

