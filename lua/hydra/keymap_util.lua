local M = {}

---@param command string
---@return string `<Cmd>..command..<CR>`
function M.cmd(command)
   return table.concat({ '<Cmd>', command, '<CR>' })
end

---@param try_cmd string
---@param catch? string
---@param catch_cmd? string
function M.get_pcmd(try_cmd, catch, catch_cmd)
   local pcommand = { 'try', try_cmd }
   if catch and catch:find('^E%d+$') then
      table.insert(pcommand, table.concat{
         'catch ', [[/^Vim\%((\a\+)\)\=:]], catch, [[:/]]
      })
   else
      table.insert(pcommand, 'catch')
   end
   if catch_cmd and catch_cmd ~= '' then
      table.insert(pcommand, catch_cmd)
   end
   table.insert(pcommand, 'endtry')
   return table.concat(pcommand, ' | ')
end

---@param try_cmd string
---@param catch? string
---@param catch_cmd? string
function M.pcmd(try_cmd, catch, catch_cmd)
   return M.cmd(M.get_pcmd(try_cmd, catch, catch_cmd))
end

-- ---@param try string
-- ---@param catch { err: string | string[], cmd: string }[]
-- local function pcmd(try, catch) -- {{{
--    -- { 'c', cmd [[try | close | catch /^Vim\%((\a\+)\)\=:E444:/ | endtry]] },
--    local command = { 'try', try }
--    for _, c in ipairs(catch) do
--       local err, catch_cmd = unpack(c)
--       if err:find('^E%d+$') then
--          table.insert(command, table.concat{
--             'catch ', [[/^Vim\%((\a\+)\)\=:]], err, [[:/]]
--          })
--       elseif err == '' then
--          table.insert(command, 'catch')
--       end
--       if catch_cmd ~= '' then
--          table.insert(command, catch_cmd)
--       end
--    end
--    table.insert(command, 'endtry')
--    -- return table.concat(command, ' | ')
--    -- return table.concat(command, '\n')
--    return table.concat(command, string.char(10) --[[\n]])
-- end -- }}}

return M
