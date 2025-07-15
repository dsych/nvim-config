local map_key = require("dsych_config.utils").map_key
local utils = require("dsych_config.utils")

-- increase timeout between keys
vim.opt.timeoutlen = 1500

-- Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
-- delays and poor user experience.
vim.opt.updatetime = 300

-- TextEdit might fail if hidden is not set.
vim.opt.hidden = true

-- Some servers have issues with backup files
vim.opt.backup = false
vim.opt.writebackup = false

-- Give more space for displaying messages.
vim.opt.cmdheight = 2

-- Don't pass messages to |ins-completion-menu|.
vim.opt.shortmess:append("c")

-- Always show the signcolumn, otherwise it would shift the text each time
-- diagnostics appear/become resolved.
vim.opt.signcolumn = "yes:2"

-- remap leader to space
map_key("n", "<space>", "<Nop>")
vim.g.mapleader = " "
vim.g.localleader = "\\"

-- Sets how many lines of history VIM has to remember
vim.opt.history = 500

-- Necessary  for lots of cool vim things
vim.opt.compatible = false

-- This shows what you are typing as a command.  I love this!
vim.opt.showcmd = true

-- automatically reload the current buffer if an external program modified it
vim.opt.autoread = true

-- highlight the current line
vim.opt.cursorline = true

-- highlight the current column
vim.opt.cursorcolumn = false

-- disable line wrapping
vim.opt.wrap = false

-- Disable mouse for all modes
vim.opt.mouse = nil

------------------------------------------------------------------------------------------------------------------------------
-- => VIM user interface
------------------------------------------------------------------------------------------------------------------------------
-- Set 7 lines to the cursor - when moving vertically using j/k
vim.opt.so = 7

-- Turn on the Wild menu, command completion in the command mode
vim.opt.wildmenu = true

-- Ignore compiled files
vim.opt.wildignore = "*.o,*~,*.pyc"
if vim.fn.has("win16") or vim.fn.has("win32") then
	vim.opt.wildignore:append(".git\\*,.hg\\*,.svn\\*")
else
	vim.opt.wildignore:append("*/.git/*,*/.hg/*,*/.svn/*,*/.DS_Store")
end

--Always show current position
vim.opt.ruler = true

-- Configure backspace so it acts as it should act
vim.opt.backspace = "eol,start,indent"
vim.opt.whichwrap:append("<,>,h,l")

-- Ignore case when searching
vim.opt.ignorecase = true

-- When searching try to be smart about cases
vim.opt.smartcase = true

-- Highlight search results
vim.opt.hlsearch = true

-- Makes search act like search in modern browsers
vim.opt.incsearch = true

-- For regular expressions turn magic on
vim.opt.magic = true

-- Show matching brackets when text indicator is over them
vim.opt.showmatch = true
-- How many tenths of a second to blink when matching brackets
vim.opt.mat = 2

-- No annoying sound on errors
vim.opt.errorbells = false
vim.opt.visualbell = false
-- vim.opt.t_vb=nil
vim.opt.tm = 500

-- set relative line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- automatically toggle number and relativenumber in insert mode
-- utils.toggle_relative_numbers(true)

vim.opt.foldmethod = "marker"

vim.opt.splitkeep = "cursor"

------------------------------------------------------------------------------------------------------------------------------
-- => Text, tab and indent related
------------------------------------------------------------------------------------------------------------------------------
-- Use spaces instead of tabs
vim.opt.expandtab = true

-- vim.opt.indent width
vim.opt.tabstop = 4

-- vim.opt.configure << and >> to be the same number of spaces as tabstop
vim.opt.shiftwidth = 0

-- Be smart when using tabs ;)
vim.opt.smarttab = true

------------------------------------------------------------
-- => Status line
------------------------------------------------------------
-- Always show the status line
vim.opt.laststatus = 2

------------------------------------------------------------
-- => Shell
------------------------------------------------------------
if string.gmatch(vim.opt.shell:get(), "zsh") then
	-- spawn login shell instead of regular shell to take full advantage of
	-- aliases and other shell specific configurations
	vim.opt.shellcmdflag = "-i -l -c"
end

vim.cmd[[
	let &t_Cs = "\e[4:3m"
	let &t_Ce = "\e[4:0m"
]]

------------------------------------------------------------
-- => Clipboard
------------------------------------------------------------
vim.g.clipboard = "osc52"
