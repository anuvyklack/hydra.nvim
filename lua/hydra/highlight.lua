local M = {}
local once = require('hydra.util').once

function M.get_hl(name)
   if vim.o.termguicolors then
      return vim.api.nvim_get_hl_by_name(name, true)
   else
      return vim.api.nvim_get_hl_by_name(name, false)
   end
end

local function create_statusline_hl_groups()
   local name, settings
   for _, color in ipairs({ 'Red', 'Blue', 'Amaranth', 'Teal', 'Pink' }) do
      settings = vim.tbl_deep_extend('force',
         M.get_hl('StatusLine'),
         M.get_hl(string.format('Hydra%s', color))
      )
      name = string.format('HydraStatusLine%s', color)
      vim.api.nvim_set_hl(0, name, settings)
   end
end

M.create_statusline_hl_groups = once(create_statusline_hl_groups)

-- local source = 'HydraRed'
-- print(vim.fn.hlID(source))
-- -- vim.fn.synIDattr(vim.fn.hlID(source), key)
-- print(vim.fn.synIDattr(vim.fn.hlID(source), 'fg'))

-- function util.hl_inherit(name, source, settings)
--    local keys = {
--       'fg',
--       'bg',
--       'bold',
--       'italic',
--       'reverse',
--       'standout',
--       'underline',
--       'undercurl',
--       'strikethrough',
--    }
--    for _, key in ipairs(keys) do
--       if not settings[key] then
--          local v = vim.fn.synIDattr(vim.fn.hlID(source), key)
--          if key == 'fg' or key == 'bg' then
--             local n = tonumber(v, 10)
--             v = type(n) == 'number' and n or v
--          else
--             v = v == 1
--          end
--          settings[key] = v == '' and 'NONE' or v
--       end
--    end
--    vim.api.nvim_set_hl(0, name, settings)
-- end

return M
