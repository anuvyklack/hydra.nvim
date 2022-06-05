local function hl(name, val)
   vim.api.nvim_set_hl(0, name, val)
end

hl('HydraRed',     { fg = '#f2594b', bold = true, default = true })
hl('HydraBlue',    { fg = '#0091f7', bold = true, default = true })
hl('HydraAmarant', { fg = '#FF355E', bold = true, default = true })
hl('HydraTeal',    { fg = '#009090', bold = true, default = true })
hl('HydraPink',    { fg = '#f766ad', bold = true, default = true })

hl('HydraHint', { link = 'NormalFloat' })


-- TODO: find out how to global clear namespace.

-- Restore options overridden by Hydra if it was emergency leaved with <C-c>.
local function emergency_exit(keys)
   if _G.active_hydra and
      keys == vim.api.nvim_replace_termcodes('<C-c>', true, true, true)
   then
      vim.schedule(function()
         _G.active_hydra:_post()
         _G.active_hydra = nil
      end)
   end
end

vim.on_key(emergency_exit, vim.api.nvim_create_namespace('hydra.plugin'))
