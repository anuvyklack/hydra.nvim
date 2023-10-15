local M = {}

-- The "report_" functions have been deprecated, so use the new ones if defined.
local health_start = vim.health.start or vim.health.report_start
local health_warn = vim.health.warn or vim.health.report_warn
local health_ok = vim.health.ok or vim.health.report_ok

health_start("Hydra: Checking settings")

local function check_timeoutlen_option()
	-- check timeoutlen
	if vim.o.timeoutlen < 300 then
		local message = [[
            Your current `timeoutlen` value is %d which might be too small to
            make each mapping working!
            It's recommended to use %d for the `timeoutlen` option!
        ]]
		health_warn(message:format(vim.o.timeoutlen, 300))
	else
		local message = [[
            `timeoutlen` (value: %d) is set to a good value.
        ]]

		health_ok(message:format(vim.o.timeoutlen))
	end
end

M.check = function()
	check_timeoutlen_option()
end

return M
