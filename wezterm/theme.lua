--- @type Wezterm
local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

local function get_appearance()
	if wezterm.gui then
		return wezterm.gui.get_appearance()
	end
	return "Dark"
end

M.get_palette_commands = function ()
	return {
		{
			brief = "Switch theme",
			-- icon = 'md_rename_box',

			action = wezterm.action_callback(function(window, pane)
				M.theme_switcher(window, pane, "/home/dsych/.config/wezterm/wezterm.lua", get_appearance())
			end),
		},
	}
end

M.theme_switcher = function(window, pane, config_path, theme_mode)
	-- get builting color schemes
	local schemes = wezterm.get_builtin_color_schemes()
	local choices = {}

	-- populate theme names in choices list
	for key, _ in pairs(schemes) do
		table.insert(choices, { label = tostring(key) })
	end

	-- sort choices list
	table.sort(choices, function(c1, c2)
		return c1.label < c2.label
	end)

	window:perform_action(
		act.InputSelector({
			title = string.format("Pick a Theme (%s Mode)!", theme_mode),
			choices = choices,
			fuzzy = true,

			-- execute 'sed' shell command to replace the line
			-- responsible of colorscheme in my config
			action = wezterm.action_callback(function(inner_window, inner_pane, _, label)
				local args = {
					"sed",
					"-E",
                    "-i",
                    "''",
					string.format([[s/( *return *)"[a-zA-Z-]*"( *-- *%s *Mode)/\1"%s"\2/]], theme_mode, label),
					config_path,
				}
                wezterm.log_info(args)
                wezterm.background_child_process(args)
			end),
		}),
		pane
	)
end

return M
