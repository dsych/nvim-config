local map_key = require("dsych_config.utils").map_key
local utils = require("dsych_config.utils")

-- escape insert mode with jk
map_key("i", "jk", "<esc>")

-- quickly saving with <leader>
map_key("n", "<leader>w", ":write<cr>")
map_key("n", "<leader>q", ":quit<cr>")

------------------------------------------------------------
-- => Visual mode related
------------------------------------------------------------
-- Visual mode pressing * or # searches for the current selection
-- Super useful! From an idea by Michael Naumann
map_key("v", "*", ":<C-u>call VisualSelection('', '')<CR>/<C-R>=@/<CR><CR>")
map_key("v", "#", ":<C-u>call VisualSelection('', '')<CR>?<C-R>=@/<CR><CR>")

------------------------------------------------------------------------------------------------------------------------------
-- => Moving around, tabs, windows and buffers
------------------------------------------------------------------------------------------------------------------------------

-- Disable highlight when <leader><cr> is pressed
map_key("n", "<leader><cr>", "<cmd>noh<cr>")

-- Smart way to move between windows
map_key("n", "<C-j>", "<C-W>j")
map_key("n", "<C-k>", "<C-W>k")
map_key("n", "<C-h>", "<C-W>h")
map_key("n", "<C-l>", "<C-W>l")

-- resize windows
map_key("n", "<M-{>", ":<c-u>resize -5<cr>")
map_key("n", "<M-}>", ":<c-u>resize +5<cr>")
map_key("n", "<M-lt>", ":<c-u>vertical resize -5<cr>")
map_key("n", "<M->>", ":<c-u>vertical resize +5<cr>")

-- Useful mappings for managing tabs
map_key("n", "<leader>tn", ":tabnew<cr>")
map_key("n", "<leader>to", ":tabonly<cr>")
map_key("n", "<leader>td", ":tabclose<cr>")
map_key("n", "<leader>tm", ":tabmove")
map_key("n", "<leader>t<leader>", ":tabnext<cr>")
-- Opens a new tab with the current buffer's path
-- Super useful when editing files in the same directory
map_key("n", "<leader>te", ":tabedit <C-r>=expand('%:p:h')<cr>/")

map_key("n", "<leader>tne", "<cmd>tabedit % <cr>")

-- Switch CWD to the directory of the open buffer
map_key("n", "<leader>cd", "<cmd>lcd %:p:h<cr>:pwd<cr>")

------------------------------------------------------------------------------------------------------------------------------
-- => Editing mappings
------------------------------------------------------------------------------------------------------------------------------
-- Remap VIM 0 to first non-blank character
map_key("n", "0", "^")

-- Move a line of text using ALT+[jk] or Command+[jk] on mac
map_key("n", "<M-j>", "mz:m+<cr>`z")
map_key("n", "<M-k>", "mz:m-2<cr>`z")
map_key("v", "<M-j>", ":m'>+<cr>`<my`>mzgv`yo`z")
map_key("v", "<M-k>", ":m'<-2<cr>`>my`<mzgv`yo`z")

------------------------------------------------------------------------------------------------------------------------------
-- => convenience mappings
------------------------------------------------------------------------------------------------------------------------------
map_key("n", "<leader>z", function()
	vim.opt.spell = not vim.opt.spell:get()
	utils.load_spell_file()
end)

-- for configs
map_key("n", "<leader>ne", "<cmd>edit $MYVIMRC<cr>")
map_key("n", "<leader>nE", ":tabnew <bar> :edit $MYVIMRC<cr>")
map_key("n", "<leader>na", ":tabnew <bar> :edit ~/.config/nvim/additional<cr>")

-- insert mode deletion
map_key("i", "<M-l>", "<del>")
map_key("i", "<M-h>", "<bs>")

-- pre/a-ppend line without moving cursor
map_key("n", "<leader>o", ":<C-u>call append(line('.'),   repeat([''], v:count1))<CR>")
map_key("n", "<leader>O", ":<C-u>call append(line('.')-1, repeat([''], v:count1))<CR>")

-- navigate quickfix with ease
map_key("n", "]q", "<cmd>cnext<cr>")
map_key("n", "[q", "<cmd>cprev<cr>")
map_key("n", "qo", "<cmd>copen<cr>")
map_key("n", "qc", "<cmd>cclose<cr>")

------------------------------------------------------------------------------------------------------------------------------
-- => Command mode related
------------------------------------------------------------------------------------------------------------------------------
-- Bash like keys for the command line
map_key("c", "<C-A>", "<Home>")
map_key("c", "<C-E>", "<End>")
map_key("c", "<C-K>", "<C-U>")

map_key("c", "<C-P>", "<Up>")
map_key("c", "<C-N>", "<Down>")
