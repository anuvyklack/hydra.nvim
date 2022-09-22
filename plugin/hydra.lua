local function hl(name, val)
   vim.api.nvim_set_hl(0, name, val)
end

hl('HydraRed',      { fg = '#FF5733', bold = true, default = true })
hl('HydraBlue',     { fg = '#5EBCF6', bold = true, default = true })
hl('HydraAmaranth', { fg = '#ff1757', bold = true, default = true })
hl('HydraTeal',     { fg = '#00a1a1', bold = true, default = true })
hl('HydraPink',     { fg = '#ff55de', bold = true, default = true })

hl('HydraHint', { link = 'NormalFloat', default = true })
hl('HydraBorder', { link = 'FloatBorder', default = true })


-- local ns_id = vim.api.nvim_create_namespace('hydra.plugin')
--
-- -- Restore options overridden by Hydra if it was emergency leaved with <C-c>.
-- local function emergency_exit(keys)
--    if _G.active_hydra and
--       keys == vim.api.nvim_replace_termcodes('<C-c>', true, true, true)
--    then
--       vim.schedule(function()
--          _G.active_hydra:_post()
--          _G.active_hydra = nil
--       end)
--    end
-- end
--
-- vim.on_key(emergency_exit, ns_id)
-- vim.on_key(nil, ns_id)
