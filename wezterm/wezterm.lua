local wezterm = require 'wezterm'
local config = {}

local is_night_in_est = function ()
				-- does not account for daylight savings
				local est_hour = tonumber(os.date("%H", os.time(os.date("!*t")) - 4 * 60 * 60))

				return est_hour < 7 or est_hour > 21
end

-- config.color_scheme = 'Batman'
config.color_scheme = is_night_in_est() and 'Violet Dark' or 'Violet Light'

config.font_size = 14
config.cursor_blink_rate = 1000
config.default_cursor_style = 'BlinkingBlock'
config.enable_scroll_bar = true
-- config.ssh_backend = "Ssh2"
-- config.ssh_domains = {
--   {
--     name = 'devbox',
--     remote_address = 'dev-dsk-dsych.aka.corp.amazon.com',
--     username = 'dsych',
--     multiplexing = "WezTerm",
--     -- no_agent_auth = true,
--   }
-- }
config.unix_domains = {
  {
    name = 'unix',
  },
}
config.default_gui_startup_args = { 'connect', 'unix' }

-- timeout_milliseconds defaults to 1000 and can be omitted
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }
config.keys = {
  {
    key = 'r',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ReloadConfiguration,
  },
  {
    key = '"',
    mods = 'LEADER|SHIFT',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = '%',
    mods = 'LEADER|SHIFT',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'n',
    mods = 'LEADER',
    action = wezterm.action.ActivateTabRelative(1),
  },
  {
    key = 'p',
    mods = 'LEADER',
    action = wezterm.action.ActivateTabRelative(-1),
  },
  {
    key = 'c',
    mods = 'LEADER',
    action = wezterm.action.SpawnTab 'CurrentPaneDomain',
  },
  {
    key = 'd',
    mods = 'LEADER',
    action = wezterm.action.DetachDomain 'CurrentPaneDomain',
  },
  {
    key = ':',
    mods = 'LEADER|SHIFT',
    action = wezterm.action.ShowLauncher
  },
  {
    key = 'w',
    mods = 'LEADER',
    action = wezterm.action.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' }
  },
  {
    key = 'z',
    mods = 'LEADER',
    action = wezterm.action.TogglePaneZoomState,
  },
  {
    key = 'f',
    mods = 'LEADER',
    action = wezterm.action.Search {CaseInSensitiveString = ""},
  },
  {
    key = 's',
    mods = 'LEADER',
    action = wezterm.action.ActivateCopyMode,
  },
  {
    key = 'x',
    mods = 'LEADER',
    action = wezterm.action.CloseCurrentPane { confirm = false },
  },
  {
    key = '&',
    mods = 'LEADER|SHIFT',
    action = wezterm.action.CloseCurrentTab { confirm = false },
  },
  {
    key = 'o',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection 'Next'
  },
  {
    key = 'O',
    mods = 'LEADER|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Prev'
  },
  {
    key = ']',
    mods = 'LEADER',
    action = wezterm.action.PasteFrom 'Clipboard'
  },
  {
    key = 'H',
    mods = 'ALT|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Left',
  },
  {
    key = 'L',
    mods = 'ALT|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Right',
  },
  {
    key = 'K',
    mods = 'ALT|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Up',
  },
  {
    key = 'J',
    mods = 'ALT|SHIFT',
    action = wezterm.action.ActivatePaneDirection 'Down',
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
    key = 'a',
    mods = 'LEADER|CTRL',
    action = wezterm.action.SendString '\x01',
  },
}



return config
