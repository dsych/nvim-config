local M = {}

M.setup = function()
	local gl = require("galaxyline")
	local gls = gl.section
	local extension = require("galaxyline.provider_extensions")
	local condition = require("galaxyline.condition")
	local diag = require("galaxyline.provider_diagnostic")
	local fileinfo = require("galaxyline.provider_fileinfo")

	gl.short_line_list = {
		"LuaTree",
		"vista",
		"dbui",
		"startify",
		"term",
		"nerdtree",
		"fugitive",
		"fugitiveblame",
		"plug",
	}

	local icons = {
		rounded_left_filled = "",
		rounded_right_filled = "",
		arrow_left_filled = "", -- e0b2
		arrow_right_filled = "", -- e0b0
		arrow_left = "", -- e0b3
		arrow_right = "", -- e0b1
		ghost = "",
		warn = "",
		info = "",
		error = "",
		hint = "",
		branch = "",
		dotdotdot = "…",
		line_number = "",
	}

	-- local theme_colors = require'solarized.colors'.getColors()
	local theme_colors = {
		none = "none",
		base02 = "#073642",
		red = "#dc322f",
		green = "#859900",
		yellow = "#b58900",
		blue = "#268bd2",
		magenta = "#d33682",
		cyan = "#2aa198",
		base2 = "#eee8d5",
		base03 = "#002b36",
		back = "#002b36",
		orange = "#cb4b16",
		base01 = "#586e75",
		base00 = "#657b83",
		base0 = "#839496",
		violet = "#6c71c4",
		base1 = "#93a1a1",
		base3 = "#fdf6e3",
		err_bg = "#fdf6e3",
	}
	local color_overrides = {
		bg = theme_colors.base02,
	}

	local colors = vim.tbl_deep_extend("force", theme_colors, color_overrides)

	local get_mode = function()
		local mode_colors = {
			[110] = { "NORMAL", colors.blue, colors.bg },
			[105] = { "INSERT", colors.cyan, colors.bg },
			[99] = { "COMMAND", colors.orange, colors.bg },
			[116] = { "TERMINAL", colors.blue, colors.bg },
			[118] = { "VISUAL", colors.violet, colors.bg },
			[22] = { "V-BLOCK", colors.violet, colors.bg },
			[86] = { "V-LINE", colors.violet, colors.bg },
			[82] = { "REPLACE", colors.red, colors.bg },
			[115] = { "SELECT", colors.red, colors.bg },
			[83] = { "S-LINE", colors.red, colors.bg },
		}

		local mode_data = mode_colors[vim.fn.mode():byte()]
		if mode_data ~= nil then
			return mode_data
		end
	end

	local function check_width_and_git_and_buffer()
		return condition.check_git_workspace() and condition.buffer_not_empty()
	end

	local check_buffer_and_width = function()
		return condition.buffer_not_empty() and condition.hide_in_width()
	end

	local function highlight(group, bg, fg, gui)
		if gui ~= nil and gui ~= "" then
			vim.api.nvim_command(("hi %s guibg=%s guifg=%s gui=%s"):format(group, bg, fg, gui))
		elseif bg == nil then
			vim.api.nvim_command(("hi %s guifg=%s"):format(group, fg))
		else
			vim.api.nvim_command(("hi %s guibg=%s guifg=%s"):format(group, bg, fg))
		end
	end

	local function trailing_whitespace()
		local trail = vim.fn.search("\\s$", "nw")
		if trail ~= 0 then
			return " "
		else
			return nil
		end
	end

	TrailingWhiteSpace = trailing_whitespace

	function has_file_type()
		local f_type = vim.bo.filetype
		if not f_type or f_type == "" then
			return false
		end
		return true
	end

	local buffer_not_empty = function()
		if vim.fn.empty(vim.fn.expand("%:t")) ~= 1 then
			return true
		end
		return false
	end

	local function split(str, sep)
		local res = {}
		for w in str:gmatch("([^" .. sep .. "]*)") do
			if w ~= "" then
				table.insert(res, w)
			end
		end
		return res
	end

	local FilePathShortProvider = function()
		local fp = vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.:h")
		local tbl = split(fp, "/")
		local len = #tbl

		if len > 2 and tbl[1] ~= "~" then
			return icons.dotdotdot .. "/" .. table.concat(tbl, "/", len - 1) .. "/"
		else
			return fp .. "/"
		end
	end

	local checkwidth = function()
		local squeeze_width = vim.fn.winwidth(0) / 2
		if squeeze_width > 40 then
			return true
		end
		return false
	end

	local BracketProvider = function(icon, cond)
		return function()
			local result

			if cond == true or cond == false then
				result = cond
			else
				result = cond()
			end

			if result ~= nil and result ~= "" then
				return icon
			end
		end
	end

	gls.left = {
		{
			GhostLeftBracket = {
				provider = BracketProvider(icons.rounded_left_filled, true),
				highlight = "GalaxyViModeNestedInv",
			},
		},
		{
			Ghost = {
				provider = BracketProvider(icons.ghost, true),
				highlight = "GalaxyViModeInv",
			},
		},
		{
			ViModeLeftBracket = {
				provider = BracketProvider(icons.rounded_right_filled, true),
				highlight = "GalaxyViMode",
			},
		},
		{
			ViMode = {
				provider = function()
					local m = get_mode()
					if m == nil then
						return
					end

					local label, mode_color, mode_nested = unpack(m)
					highlight("GalaxyViMode", mode_color, mode_nested)
					highlight("GalaxyViModeInv", mode_nested, mode_color)
					highlight("GalaxyViModeNested", mode_nested, colors.bg)
					highlight("GalaxyViModeNestedInv", colors.bg, mode_nested)
					highlight("GalaxyPercentBracket", colors.bg, mode_color)

					highlight("GalaxyGitLCBracket", mode_nested, mode_color)

					if condition.buffer_not_empty() then
						highlight("GalaxyViModeBracket", mode_nested, mode_color)
					else
						if condition.check_git_workspace() then
							highlight("GalaxyGitLCBracket", colors.bg, mode_color)
						end
						highlight("GalaxyViModeBracket", colors.bg, mode_color)
					end
					return "  " .. label .. " "
				end,
			},
		},
		{
			ViModeBracket = {
				provider = BracketProvider(icons.arrow_right_filled, true),
				highlight = "GalaxyViModeBracket",
			},
		},
		{
			GitIcon = {
				provider = BracketProvider("  " .. icons.branch .. " ", true),
				condition = check_width_and_git_and_buffer,
				highlight = "GalaxyViModeInv",
			},
		},
		{
			GitBranch = {
				provider = function()
					local vcs = require("galaxyline.provider_vcs")
					local branch_name = vcs.get_git_branch()
					if not branch_name then
						return " no git "
					end
					if string.len(branch_name) > 28 then
						return string.sub(branch_name, 1, 25) .. icons.dotdotdot
					end
					return branch_name .. " "
				end,
				condition = check_width_and_git_and_buffer,
				highlight = "GalaxyViModeInv",
				separator = icons.arrow_right,
				separator_highlight = "GalaxyViModeInv",
			},
		},
		{
			FileIcon = {
				provider = function()
					local icon = fileinfo.get_file_icon()
					if condition.check_git_workspace() then
						return " " .. icon
					end

					return "  " .. icon
				end,
				condition = condition.buffer_not_empty,
				highlight = "GalaxyViModeInv",
			},
		},
		{
			FilePath = {
				provider = FilePathShortProvider,
				condition = check_buffer_and_width,
				highlight = "GalaxyViModeInv",
			},
		},
		{
			FileName = {
				provider = "FileName",
				condition = condition.buffer_not_empty,
				highlight = "GalaxyViModeInv",
				separator = icons.arrow_right_filled,
				separator_highlight = "GalaxyViModeNestedInv",
			},
		},
		{
			DiffAdd = {
				provider = "DiffAdd",
				condition = checkwidth,
				icon = " ",
				highlight = { colors.green, colors.bg },
			},
		},
		{
			DiffModified = {
				provider = "DiffModified",
				condition = checkwidth,
				icon = " ",
				highlight = { colors.orange, colors.bg },
			},
		},
		{
			DiffRemove = {
				provider = "DiffRemove",
				condition = checkwidth,
				icon = " ",
				highlight = { colors.red, colors.bg },
			},
		},
		{
			LspStatus = {
				provider = {
					BracketProvider(icons.arrow_right, true),
					function()
						return require("lsp-status").status()
					end,
				},
				highlight = "GalaxyViModeInv",
			},
		},
	}

	highlight("GalaxyDiagnosticError", colors.red, colors.bg)
	highlight("GalaxyDiagnosticErrorInv", colors.bg, colors.red)

	highlight("GalaxyDiagnosticWarn", colors.yellow, colors.bg)
	highlight("GalaxyDiagnosticWarnInv", colors.bg, colors.yellow)

	highlight("GalaxyDiagnosticInfo", colors.violet, colors.bg)
	highlight("GalaxyDiagnosticInfoInv", colors.bg, colors.violet)

	local LineColumnProvider = function()
		local line_column = fileinfo.line_column()
		line_column = line_column:gsub("%s+", "")
		return " " .. icons.line_number .. line_column
	end

	local PercentProvider = function()
		local line_column = fileinfo.current_line_percent()
		line_column = line_column:gsub("%s+", "")
		return line_column .. " ☰"
	end

	gls.right = {
		{
			DiagnosticErrorLeftBracket = {
				provider = BracketProvider(icons.rounded_left_filled, diag.get_diagnostic_error),
				highlight = "GalaxyDiagnosticErrorInv",
				condition = condition.buffer_not_empty,
			},
		},
		{
			DiagnosticError = {
				provider = "DiagnosticError",
				icon = icons.error .. " ",
				highlight = "GalaxyDiagnosticError",
				condition = condition.buffer_not_empty,
			},
		},
		{
			DiagnosticErrorRightBracket = {
				provider = {
					BracketProvider(icons.rounded_right_filled, diag.get_diagnostic_error),
					BracketProvider(" ", diag.get_diagnostic_error),
				},
				highlight = "GalaxyDiagnosticErrorInv",
				condition = condition.buffer_not_empty,
			},
		},
		{
			DiagnosticWarnLeftBracket = {
				provider = BracketProvider(icons.rounded_left_filled, diag.get_diagnostic_warn),
				highlight = "GalaxyDiagnosticWarnInv",
				condition = condition.buffer_not_empty,
			},
		},
		{
			DiagnosticWarn = {
				provider = "DiagnosticWarn",
				highlight = "GalaxyDiagnosticWarn",
				icon = icons.warn .. " ",
				condition = condition.buffer_not_empty,
			},
		},
		{
			DiagnosticWarnRightBracket = {
				provider = {
					BracketProvider(icons.rounded_right_filled, diag.get_diagnostic_warn),
					BracketProvider(" ", diag.get_diagnostic_warn),
				},
				highlight = "GalaxyDiagnosticWarnInv",
				condition = condition.buffer_not_empty,
			},
		},
		{
			DiagnosticInfoLeftBracket = {
				provider = BracketProvider(icons.rounded_left_filled, diag.get_diagnostic_info),
				highlight = "GalaxyDiagnosticInfoInv",
			},
		},
		{
			DiagnosticInfo = {
				provider = "DiagnosticInfo",
				icon = icons.info .. " ",
				highlight = "GalaxyDiagnosticInfo",
				condition = check_width_and_git_and_buffer,
			},
		},
		{
			DiagnosticInfoRightBracket = {
				provider = {
					BracketProvider(icons.rounded_right_filled, diag.get_diagnostic_info),
					BracketProvider(" ", diag.get_diagnostic_info),
				},
				highlight = "GalaxyDiagnosticInfoInv",
				condition = condition.buffer_not_empty,
			},
		},
		{
			LineColumn = {
				provider = {
					LineColumnProvider,
					function()
						return " "
					end,
				},
				highlight = "GalaxyViMode",
				separator = icons.arrow_left_filled,
				separator_highlight = "GalaxyGitLCBracket",
			},
		},
		{
			PerCent = {
				provider = {
					PercentProvider,
				},
				highlight = "GalaxyViMode",
				separator = icons.arrow_left .. " ",
				separator_highlight = "GalaxyViModeLeftBracket",
			},
		},
		{
			PercentRightBracket = {
				provider = BracketProvider(icons.rounded_right_filled, true),
				highlight = "GalaxyPercentBracket",
			},
		},
	}

	gls.short_line_left = {
		{
			GhostLeftBracketShort = {
				provider = BracketProvider(icons.rounded_left_filled, true),
				highlight = { colors.base3, colors.bg },
			},
		},
		{
			GhostShort = {
				provider = BracketProvider(icons.ghost, true),
				highlight = { colors.bg, colors.base3 },
			},
		},
		{
			GhostRightBracketShort = {
				provider = BracketProvider(icons.rounded_right_filled, true),
				highlight = { colors.base3, colors.bg },
			},
		},
		{
			FileIconShort = {
				provider = {
					function()
						return "  "
					end,
					"FileIcon",
				},
				condition = condition.buffer_not_empty,
				highlight = {
					fileinfo.get_file_icon,
					colors.bg,
				},
			},
		},
		{
			FilePathShort = {
				provider = FilePathShortProvider,
				condition = condition.buffer_not_empty,
				highlight = { colors.base3, colors.bg },
			},
		},
		{
			FileNameShort = {
				provider = "FileName",
				condition = condition.buffer_not_empty,
				highlight = { colors.base3, colors.bg },
			},
		},
	}

	gls.short_line_right = {
		{
			ShortLineColumn = {
				provider = {
					LineColumnProvider,
					function()
						return " "
					end,
				},
				highlight = { colors.base3, colors.bg },
			},
		},
		{
			ShortPerCent = {
				provider = {
					PercentProvider,
				},
				separator = icons.arrow_left .. " ",
				highlight = { colors.base3, colors.bg },
			},
		},
	}
end

return M
