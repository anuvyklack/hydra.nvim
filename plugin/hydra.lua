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
