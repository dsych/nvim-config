--- @type Wezterm
local wezterm = require("wezterm")

--- @type Config
local config = {}
local icons = wezterm.nerdfonts

local force_dark_mode = false
-- local is_night_in_est = function()
--   -- does not account for daylight savings
--   local est_hour = tonumber(os.date("%H", os.time(os.date("!*t")) - 4 * 60 * 60))

--   return est_hour < 7 or est_hour > 21
-- end

-- config.color_scheme = (is_night_in_est() or force_dark_mode) and 'GruvboxDark' or 'GruvboxLight'

config.status_update_interval = 5000
config.use_fancy_tab_bar = true
config.window_frame = {
	font = wezterm.font("Berkeley Mono", { weight = "Bold" }),
	font_size = 16,
}

config.native_macos_fullscreen_mode = true

wezterm.on("format-tab-title", function(tab)
	local pane = tab.active_pane
	local title = pane.title

	local zoomed = ""
	if pane.is_zoomed then
		zoomed = icons.oct_zoom_in .. " "
	end

	if pane.domain_name then
		title = zoomed .. title .. " (" .. pane.domain_name .. ")"
	end

	return string.format("%s %s ", tab.tab_index + 1, title)
end)

-- wezterm.on('format-window-title', function(tab, pane, tabs, panes, config)
--   local zoomed = ''
--   if tab.active_pane.is_zoomed then
--     zoomed = '[Z] '
--   end

--   local index = ''
--   if #tabs > 1 then
--     index = string.format('[%d/%d] ', tab.tab_index + 1, #tabs)
--   end

--   return zoomed .. index .. tab.active_pane.title
-- end)

config.tab_bar_at_bottom = true
-- wezterm.on("update-status", function(window, pane)
-- 	window:set_left_status(wezterm.format({
--     {
--       Text = string.format("%s: %s", pane:get_domain_name(), pane:get_foreground_process_name())
--     }
--   }))
-- end)

local function query_spotify(body)
	local success, output, stderr = wezterm.run_child_process({
		"osascript",
		"-e",
		string.format(
			[[
tell application "Spotify"
	return %s
end tell]],
			body
		),
	})

	if success then
		output, _ = string.gsub(output, "[\n\r]", "")
		return output, nil
	else
		return nil, stderr
	end
end

local function get_currently_playing_song(max_width)
	local currently_playing, err = query_spotify("current track's name")
	if err or currently_playing == nil then
		return nil, err
	end

	if string.len(currently_playing) > max_width then
		currently_playing = string.sub(currently_playing, -max_width)
	end

	return currently_playing, nil
end

local function get_player_status()
	local status, stderr = query_spotify("player state as string")

	if not status then
		return nil, stderr
	elseif status == "playing" then
		return icons.md_play .. " "
	elseif status == "paused" then
		return icons.md_stop .. " "
	end
end

local function format_date_time()
	local utc_time = wezterm.strftime_utc("%H:%M")

	local date = wezterm.strftime("%Y/%m/%d %H:%M")
	local formatted_date_time = string.format("%s %s (%s)", icons.md_clock, date, utc_time)
	return formatted_date_time
end

local function format_currently_playing()
	local currently_playing, stderr = get_currently_playing_song(50)

	if currently_playing then
		local player_status = get_player_status()
		return (player_status or "") .. currently_playing
	else
		wezterm.log_error(stderr)
		return ""
	end
end

local function format_battery_status()
	local formatted_batteries = {}

	-- An entry for each battery (typically 0 or 1 battery)
	for _, b in ipairs(wezterm.battery_info()) do
		local battery_icon = icons.fa_battery_full
		if b.state_of_charge > 0.45 and b.state_of_charge <= 0.66 then
			battery_icon = icons.fa_battery_half
		elseif b.state_of_charge > 0.66 and b.state_of_charge <= 0.9 then
			battery_icon = icons.fa_battery_three_quarters
		elseif b.state_of_charge > 0.1 and b.state_of_charge <= 0.45 then
			battery_icon = icons.fa_battery_quarter
		elseif b.state_of_charge > 0.9 then
			battery_icon = icons.fa_battery_full
		else
			battery_icon = icons.fa_battery_empty
		end
		local battery_time = nil

		if b.state == "Charging" then
			battery_time = b.time_to_full
		elseif b.state == "Discharging" then
			battery_time = b.time_to_empty
		end
		table.insert(
			formatted_batteries,
			string.format(
				"%s %.0f%%%s",
				battery_icon,
				b.state_of_charge * 100,
				battery_time ~= nil
						and (string.format(
							" %s%.1fH",
							(b.state == "Charging" and icons.oct_arrow_up or icons.oct_arrow_down),
							battery_time / 3600
						))
					or ""
			)
		)
	end

	return formatted_batteries
end

local function format_status_line_elements(cells)
	-- The elements to be formatted
	local elements = {}
	-- How many cells have been formatted
	local num_cells = 0

	-- Translate a cell into elements
	function push(text, is_last)
		table.insert(elements, { Text = " " .. text .. " " })
		if not is_last then
			table.insert(elements, { Text = icons.md_chevron_double_left })
		else
			table.insert(elements, { Text = " " })
		end
		num_cells = num_cells + 1
	end

	while #cells > 0 do
		local cell = table.remove(cells, 1)
		push(cell, #cells == 0)
	end
	return elements
end

wezterm.on("update-right-status", function(window, pane)
	local cells = {}
	table.insert(cells, format_currently_playing())
	for _, battery_status in ipairs(format_battery_status()) do
		table.insert(cells, battery_status)
	end
	table.insert(cells, format_date_time())

	local elements = format_status_line_elements(cells)
	window:set_right_status(wezterm.format(elements))
end)

-- wezterm.gui is not available to the mux server, so take care to
-- do something reasonable when this config is evaluated by the mux
function get_appearance()
	if wezterm.gui then
		return wezterm.gui.get_appearance()
	end
	return "Dark"
end

function scheme_for_appearance(appearance)
	if appearance:find("Dark") or force_dark_mode then
		return "rose-pine-moon" -- Dark Mode
	-- return 'GruvboxDark'
	else
		return "flexoki-light" -- Light Mode
		-- return 'GruvboxLight'
	end
end

local function get_colors()
	local color_scheme = scheme_for_appearance(get_appearance())

	local builtin_color_schemes = wezterm.color.get_builtin_schemes()
	local colors = builtin_color_schemes[color_scheme]

	colors.selection_bg = wezterm.color.parse(colors.selection_bg):lighten(0.15)

	return color_scheme, {
		[color_scheme] = colors,
	}
end

local color_scheme, overwritten_color_schemes = get_colors()

config.color_scheme = color_scheme
config.color_schemes = overwritten_color_schemes

-- config.front_end = "Software"
-- config.front_end = "WebGpu"
-- config.front_end = "OpenGL"
-- config.webgpu_power_preference = "HighPerformance"
-- config.enable_scroll_bar = true

config.font_size = 16
-- config.font = wezterm.font"B612 Mono"
-- config.font = wezterm.font"VictorMono Nerd Font"
config.font = wezterm.font("Berkeley Mono")
-- config.cursor_blink_rate = 1000
-- config.animation_fps = 1
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"
config.default_cursor_style = "BlinkingBlock"
-- config.enable_scroll_bar = false
-- config.ssh_backend = "Ssh2"
-- config.ssh_domains = {
--     {
--         name = 'dd',
--         remote_address = 'dev-dsk-dsych-1d-91c8c3cd.us-east-1.amazon.com',
--         multiplexing = 'WezTerm',
--         username = 'dsych',
--         -- ssh_backend = 'Ssh2',
--         remote_wezterm_path = "/home/dsych/.local/bin/wezterm-mux-server"
--     },
-- }
--
config.ssh_domains = {
	{
		name = "cloud-desktop",
		remote_address = "dev-dsk-dsych-1d-7770a0fc.us-east-1.amazon.com",
		ssh_option = {
			identitiesonly = "yes",
		},
		username = "dsych",
		multiplexing = "WezTerm",
		remote_wezterm_path = "/home/dsych/.local/bin/wezterm",
		-- local_echo_threshold_ms = 100,
	},
}
-- config.unix_domains = {
-- 	{
-- 		name = "unix",
-- 		local_echo_threshold_ms = 10,
-- 	},
-- 	{
-- 		name = "proxy-devbox",
-- 		proxy_command = { "ssh", "-A", "-T", "devbox", "/home/dsych/.local/bin/wezterm", "cli", "proxy" },
-- 	},
-- }

-- timeout_milliseconds defaults to 1000 and can be omitted
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }

if wezterm.gui then
	local copy_mode = wezterm.gui.default_key_tables().copy_mode
	table.insert(copy_mode, {
		key = "u",
		mods = "NONE",
		action = wezterm.action.CopyMode("PageUp"),
	})
	table.insert(copy_mode, {
		key = "d",
		mods = "NONE",
		action = wezterm.action.CopyMode("PageDown"),
	})
	table.insert(copy_mode, {
		key = "Enter",
		mods = "NONE",
		action = wezterm.action.Multiple({
			wezterm.action.CopyMode "MoveToScrollbackBottom",
			wezterm.action.CopyMode "Close",

			-- { CopyMode = "ScrollToBottom" },
			-- { CopyMode = "Close"}
			-- wezterm.action.ClearSelection,
			-- wezterm.action.CopyMode("ScrollToBottom"),

		})
	})
	table.insert(copy_mode, {
		key = "e",
		mods = "CTRL",
		action = wezterm.action.CopyMode("EditPattern"),
	})

	table.insert(copy_mode, {
		key = "n",
		mods = "CTRL",
		action = wezterm.action.CopyMode("NextMatch"),
	})
	table.insert(copy_mode, {
		key = "p",
		mods = "CTRL",
		action = wezterm.action.CopyMode("PriorMatch"),
	})

	table.insert(copy_mode, {
		key = "j",
		mods = "CTRL",
		action = wezterm.action.CopyMode("NextMatch"),
	})
	table.insert(copy_mode, {
		key = "k",
		mods = "CTRL",
		action = wezterm.action.CopyMode("PriorMatch"),
	})
	table.insert(copy_mode, {
		key = "Escape",
		mods = "NONE",
		action = wezterm.action_callback(function(window, pane)
			local has_selection = window:get_selection_text_for_pane(pane) ~= ""
			if has_selection then
				window:perform_action(wezterm.action.CopyMode "ClearSelectionMode", pane)
			else
				window:perform_action(wezterm.action.CopyMode "ClearPattern", pane)
				window:perform_action(wezterm.action.CopyMode "MoveToScrollbackBottom", pane)
				window:perform_action(wezterm.action.CopyMode "Close", pane)
			end
		end),
	})
	table.insert(copy_mode, {
		key = "*",
		mods = "SHIFT",
		-- action = wezterm.action.Multiple({
		-- 	wezterm.action.Search("CurrentSelectionOrEmptyString"),
		-- 	wezterm.action.ClearSelection
		-- })

		---
		---@param window Window
		---@param pane Pane
		action = wezterm.action_callback(function (
            window,
            pane
        )
			local selection = window:get_selection_text_for_pane(pane)

			if selection ~= "" then
				window:perform_action(wezterm.action.Search({CaseInSensitiveString = selection}), pane)
				window:perform_action(wezterm.action.CopyMode "ClearSelectionMode", pane)
				window:perform_action(wezterm.action.CopyMode "AcceptPattern", pane)
			else
				window:perform_action(wezterm.action.CopyMode { SetSelectionMode = "Word" }, pane)
			end
		end)
	})
	table.insert(copy_mode, {
		key = "/",
		mods = "NONE",
		action = wezterm.action.Search({ CaseInSensitiveString = "" }),
	})
	table.insert(copy_mode, {
		key = "?",
		mods = "NONE",
		action = wezterm.action.Search({ CaseInSensitiveString = "" }),
	})


	local search_mode = wezterm.gui.default_key_tables().search_mode
	table.insert(search_mode, {
		key = "Enter",
		mods = "NONE",
		action = wezterm.action.CopyMode("AcceptPattern"),
	})
	table.insert(search_mode, {
		key = "Escape",
		mods = "NONE",
		action = wezterm.action.Multiple({
			wezterm.action.CopyMode("ClearPattern"),
			wezterm.action.CopyMode("Close"),
		})
	})
	table.insert(search_mode, {
		key = "j",
		mods = "CTRL",
		action = wezterm.action.CopyMode("NextMatch"),
	})
	table.insert(search_mode, {
		key = "k",
		mods = "CTRL",
		action = wezterm.action.CopyMode("PriorMatch"),
	})
	table.insert(search_mode, {
		key = "w",
		mods = "CTRL",
		action = wezterm.action.CopyMode("ClearPattern"),
	})

	config.key_tables = {
		copy_mode = copy_mode,
		search_mode = search_mode,
	}
end

config.keys = {
	{
		key = "r",
		mods = "CMD|SHIFT",
		action = wezterm.action.ReloadConfiguration,
	},
	{
		key = '"',
		mods = "LEADER|SHIFT",
		action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
	{
		key = '_',
		mods = "LEADER|SHIFT",
		action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "%",
		mods = "LEADER|SHIFT",
		action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "|",
		mods = "LEADER|SHIFT",
		action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "n",
		mods = "LEADER",
		action = wezterm.action.ActivateTabRelative(1),
	},
	{
		key = "p",
		mods = "LEADER",
		action = wezterm.action.ActivateTabRelative(-1),
	},
	{
		key = "l",
		mods = "LEADER",
		action = wezterm.action.ActivateLastTab,
	},
	{
		key = "c",
		mods = "LEADER",
		action = wezterm.action.SpawnTab("CurrentPaneDomain"),
	},
	{
		key = "d",
		mods = "LEADER",
		action = wezterm.action.DetachDomain("CurrentPaneDomain"),
	},
	{
		key = ";",
		mods = "LEADER",
		action = wezterm.action.ActivateCommandPalette,
	},
	{
		key = "w",
		mods = "LEADER",
		action = wezterm.action.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }),
	},
	{
		key = "z",
		mods = "LEADER",
		action = wezterm.action.TogglePaneZoomState,
	},
	{
		key = "y",
		mods = "LEADER",
		action = wezterm.action.ActivateCopyMode,
	},
	{
		key = "x",
		mods = "LEADER",
		action = wezterm.action.CloseCurrentPane({ confirm = false }),
	},
	{
		key = "&",
		mods = "LEADER|SHIFT",
		action = wezterm.action.CloseCurrentTab({ confirm = false }),
	},
	{
		key = "o",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Next"),
	},
	{
		key = "O",
		mods = "LEADER|SHIFT",
		action = wezterm.action.ActivatePaneDirection("Prev"),
	},
	{
		key = "]",
		mods = "LEADER",
		action = wezterm.action.PasteFrom("Clipboard"),
	},
	{
		key = "[",
		mods = "LEADER",
		action = wezterm.action.Multiple({
			wezterm.action.ActivateCopyMode,
			wezterm.action.ClearSelection,
			-- wezterm.action.CopyMode { 'ClearSelectionMode' }
		}),
	},
	{
		key = "H",
		mods = "ALT|SHIFT",
		action = wezterm.action.ActivatePaneDirection("Left"),
	},
	{
		key = "L",
		mods = "ALT|SHIFT",
		action = wezterm.action.ActivatePaneDirection("Right"),
	},
	{
		key = "K",
		mods = "ALT|SHIFT",
		action = wezterm.action.ActivatePaneDirection("Up"),
	},
	{
		key = "J",
		mods = "ALT|SHIFT",
		action = wezterm.action.ActivatePaneDirection("Down"),
	},
	{

		key = "e",
		mods = "LEADER",
		action = wezterm.action.QuickSelectArgs({
			label = "open url",
			action = wezterm.action_callback(function(window, pane)
				local url = window:get_selection_text_for_pane(pane)
				wezterm.log_info("opening: " .. url)
				wezterm.open_with(url)
			end),
		}),
	},
	{
		key = "s",
		mods = "LEADER",
		action = wezterm.action.QuickSelectArgs,
	},
	{ key = "q", mods = "LEADER", action = wezterm.action.QuickSelect },
	{
		key = "/",
		mods = "LEADER",
		action = wezterm.action.Search({ CaseInSensitiveString = "" }),
	},
	{
		key = "?",
		mods = "LEADER",
		action = wezterm.action.Search({ CaseInSensitiveString = "" }),
	},

	-- Prompt for a name to use for a new workspace and switch to it.
	-- {
	--   key = 'w',
	--   mods = 'LEADER',
	--   action = wezterm.action.PromptInputLine {
	--     description = wezterm.format {
	--       { Attribute = { Intensity = 'Bold' } },
	--       { Foreground = { AnsiColor = 'Fuchsia' } },
	--       { Text = 'Enter name for new workspace' },
	--     },
	--     action = wezterm.action_callback(function(window, pane, line)
	--       -- line will be `nil` if they hit escape without entering anything
	--       -- An empty string if they just hit enter
	--       -- Or the actual line of text they wrote
	--       if line then
	--         window:perform_action(
	--           wezterm.action.SwitchToWorkspace {
	--             name = line,
	--           },
	--           pane
	--         )
	--       end
	--     end),
	--   },
	-- },
	-- Send "CTRL-A" to the terminal when pressing CTRL-A, CTRL-A
	{
		key = "a",
		mods = "LEADER|CTRL",
		action = wezterm.action.SendString("\x01"),
	},
	{
		key = "f",
		mods = "SHIFT|CMD",
		action = "ToggleFullScreen"
	},
	{
		key = "r",
		mods = "LEADER|SHIFT",
		action = wezterm.action_callback(function (window, pane)
			local success, stdout, stderr = wezterm.run_child_process { "ssh-add" }

			if success then
				window:perform_action(wezterm.action.AttachDomain "cloud-desktop", pane)
			else
				wezterm.log_error(stdout, stderr)
			end
		end)
	}
}

config.default_gui_startup_args = { "connect", "unix" }

local function merge_tables(src, dest)
	dest = dest or {}
	src = src or {}

	local result = {}

	for _, item in ipairs(src) do
		table.insert(result, item)
	end

	for _, item in ipairs(dest) do
		table.insert(result, item)
	end

	return result
end

local theme = require("theme")

wezterm.on("augment-command-palette", function()
	local commands = {
		{
			brief = "My test aug",
			-- icon = 'md_rename_box',

			action = wezterm.action_callback(function(
                window,
                pane
            )
			end),
		},
	}

	return merge_tables(commands, theme.get_palette_commands())
end)

config.term = "wezterm"

return config
