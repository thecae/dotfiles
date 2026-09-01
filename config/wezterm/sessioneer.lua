local wezterm = require("wezterm")

local M = {}

local function get_projects(pane)
	local domain = pane:get_domain_name()
	local cmd
	if domain == "local" then
		cmd = { "zoxide", "query", "-l" }
	else
		local host = domain:gsub("^SSHMUX:", "")
		cmd = { "ssh", host, "zoxide", "query", "-l" }
	end

	local choices = {}
	local success, stdout, stderr = wezterm.run_child_process(cmd)

	if success then
		for line in stdout:gmatch("[^\r\n]+") do
			table.insert(choices, { id = line, label = line })
		end
	end
	return choices
end

local function get_ssh_hosts()
	local choices = {}
	for _, dom in ipairs(wezterm.default_ssh_domains()) do
		if dom.name:match("^SSHMUX:") then
			local host = dom.name:gsub("^SSHMUX:", "")
			table.insert(choices, { id = dom.name, label = host })
		end
	end
	return choices
end

M.project_select = function()
	return wezterm.action_callback(function(window, pane)
		local domain = pane:get_domain_name()
		window:perform_action(
			wezterm.action.InputSelector({
				title = "Choose Project",
				choices = get_projects(pane), -- Runs at keypress time (because of action_callback)
				fuzzy = true,
				action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
					if id then
						local spawn = {
							cwd = id,
							domain = domain == "local" and "DefaultDomain" or { DomainName = domain },
						}
						if domain ~= "local" then
							-- wezterm-mux-server on the remote host can inherit the local
							-- client's $HOME; strip it so the remote shell recomputes its own.
							spawn.args = { "/usr/bin/env", "-u", "HOME", "fish", "-l" }
						end
						inner_window:perform_action(wezterm.action.SwitchToWorkspace({ name = label, spawn = spawn }), inner_pane)
					end
				end),
			}),
			pane
		)
	end)
end

M.ssh_select = function()
	return wezterm.action_callback(function(window, pane)
		window:perform_action(
			wezterm.action.InputSelector({
				title = "Choose SSH Host",
				choices = get_ssh_hosts(),
				fuzzy = true,
				action = wezterm.action_callback(function(_inner_window, _inner_pane, id, _label)
					if not id then
						wezterm.log_info("ssh_select: cancelled")
						return
					end

					wezterm.log_info("ssh_select: connecting to domain " .. id)
					wezterm.background_child_process({ "wezterm", "connect", id })
				end),
			}),
			pane
		)
	end)
end

return M
