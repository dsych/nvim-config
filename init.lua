------------------------------------------------------------------------------------------------------------------------------
-- => GLOBAL OVERLOADS
------------------------------------------------------------------------------------------------------------------------------
local function source_all_additional_files(dir_path)
  if vim.fn.isdirectory(dir_path) then
      local directory_content = vim.fn.readdir(dir_path, function(n) return string.match(n, ".+%.lua") ~= nil end)
      for _, d in ipairs(directory_content) do
        local filename = dir_path..'/'..d
        if vim.fn.filereadable(filename) then
            vim.api.nvim_command('source '..filename)
        end
    end
  end
end


-- load host specific configuration here
source_all_additional_files(vim.fn.stdpath('config')..'/additional/host')

------------------------------------------------------------------------------------------------------------------------------
-- => General
------------------------------------------------------------------------------------------------------------------------------
-- increase timeout between keys
vim.opt.timeoutlen=1500

-- Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
-- delays and poor user experience.
vim.opt.updatetime=300

-- TextEdit might fail if hidden is not set.
vim.opt.hidden=true

-- Some servers have issues with backup files
vim.opt.backup=false
vim.opt.writebackup=false

-- Give more space for displaying messages.
vim.opt.cmdheight=2

-- Don't pass messages to |ins-completion-menu|.
vim.opt.shortmess:append("c")

-- Always show the signcolumn, otherwise it would shift the text each time
-- diagnostics appear/become resolved.
vim.opt.signcolumn="yes:2"

local function map_key(mode, lhs, rhs, opts)
    opts = opts or {}
    vim.keymap.set(mode, lhs, rhs, vim.tbl_deep_extend("force", { noremap = true, silent = false }, opts))
end

-- remap leader to space
map_key("n", "<space>", "<Nop>")
vim.g.mapleader=" "

-- Sets how many lines of history VIM has to remember
vim.opt.history=500

-- escape insert mode with jk
map_key("i", "jk", "<esc>")

-- quickly saving with <leader>
map_key("n", "<leader>w", ":write<cr>")
map_key("n", "<leader>q", ":quit<cr>")

-- Necessary  for lots of cool vim things
vim.opt.compatible=false

-- This shows what you are typing as a command.  I love this!
vim.opt.showcmd=true

-- automatically reload the current buffer if an external program modified it
vim.opt.autoread=true

-- highlight the current line
vim.opt.cursorline=true

-- disable line wrapping
vim.opt.wrap=false

------------------------------------------------------------------------------------------------------------------------------
-- => VIM user interface
------------------------------------------------------------------------------------------------------------------------------
-- Set 7 lines to the cursor - when moving vertically using j/k
vim.opt.so=7

-- Turn on the Wild menu, command completion in the command mode
vim.opt.wildmenu=true

-- Ignore compiled files
vim.opt.wildignore="*.o,*~,*.pyc"
if vim.fn.has("win16") or vim.fn.has("win32") then
    vim.opt.wildignore:append(".git\\*,.hg\\*,.svn\\*")
else
    vim.opt.wildignore:append("*/.git/*,*/.hg/*,*/.svn/*,*/.DS_Store")
end

--Always show current position
vim.opt.ruler=true

-- Disable mouse for all modes
vim.opt.mouse=nil

-- Configure backspace so it acts as it should act
vim.opt.backspace="eol,start,indent"
vim.opt.whichwrap:append("<,>,h,l")

-- Ignore case when searching
vim.opt.ignorecase=true

-- When searching try to be smart about cases
vim.opt.smartcase=true

-- Highlight search results
vim.opt.hlsearch=true

-- Makes search act like search in modern browsers
vim.opt.incsearch=true

-- For regular expressions turn magic on
vim.opt.magic=true

-- Show matching brackets when text indicator is over them
vim.opt.showmatch=true
-- How many tenths of a second to blink when matching brackets
vim.opt.mat=2

-- No annoying sound on errors
vim.opt.errorbells=false
vim.opt.visualbell=false
-- vim.opt.t_vb=nil
vim.opt.tm=500

-- set relative line numbers
vim.opt.number=true
vim.opt.relativenumber=true
--
-- toggle to absolute line numbers in insert mode and when buffer loses focus
function ToggleRelativeNumbers(mode)
    if mode then
        vim.cmd([[
            augroup number_toggle
                autocmd!
                autocmd BufEnter,FocusGained,InsertLeave * set relativenumber
                autocmd BufLeave,FocusLost,InsertEnter   * set norelativenumber
            augroup END
        ]])
    else
        vim.cmd([[
            augroup number_toggle
                autocmd!
            augroup END
        ]])
    end
end

ToggleRelativeNumbers(true)



------------------------------------------------------------------------------------------------------------------------------
-- => Text, tab and indent related
------------------------------------------------------------------------------------------------------------------------------
-- Use spaces instead of tabs
vim.opt.expandtab = true

-- vim.opt.indent width
vim.opt.tabstop=4

-- vim.opt.configure << and >> to be the same number of spaces as tabstop
vim.opt.shiftwidth=0

-- Be smart when using tabs ;)
vim.opt.smarttab=true

------------------------------------------------------------
-- => Visual mode related
------------------------------------------------------------
-- Visual mode pressing * or # searches for the current selection
-- Super useful! From an idea by Michael Naumann
map_key("v", "*", "<cmd><C-u>call VisualSelection('', '')<CR>/<C-R>=@/<CR><CR>")
map_key("v", "#", "<cmd><C-u>call VisualSelection('', '')<CR>?<C-R>=@/<CR><CR>")

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
map_key("n", "<leader>cd", "<cmd>cd %:p:h<cr>:pwd<cr>")

-- Return to last edit position when opening files
vim.cmd([[
    augroup last_cursor_position
        autocmd!
        autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
    augroup END
]])

------------------------------------------------------------
-- => Status line
------------------------------------------------------------
-- Always show the status line
vim.opt.laststatus=2

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


-- Delete trailing white space on save, useful for some filetypes ;)
function CleanExtraSpaces()
    local save_cursor = vim.fn.getpos(".")
    local old_query = vim.fn.getreg('/')
    vim.api.nvim_command("silent! %s/\\s\\+$//e")
    vim.fn.setpos('.', save_cursor)
    vim.fn.setreg('/', old_query)
end

vim.cmd([[
    augroup remove_whitespace
        autocmd!
        autocmd BufWritePre * :lua CleanExtraSpaces()
    augroup END
]])


------------------------------------------------------------------------------------------------------------------------------
-- => convenience mappings
------------------------------------------------------------------------------------------------------------------------------
vim.cmd([[
    augroup code_spell
        autocmd!
        " turn on spell checking for all file types
        autocmd FileType * :set spelloptions=camel | :set spellcapcheck= | :set spell
        " except for the following file types
        " vim ft has poor dictionary
        autocmd FileType startify,vim :set nospell
    augroup end
]])

vim.cmd([[
    augroup markdown
      autocmd!
      autocmd FileType markdown :set textwidth=120
    augroup END
]])

local function load_spell_file()
    local syntax_spell_file = vim.fn["spell#GetSyntaxFile"](vim.opt.filetype:get())

    if vim.opt.spell:get() and vim.fn.filereadable(syntax_spell_file) then
        vim.fn["spell#LoadSyntaxFile"]()
    end
end

map_key("n", "<leader>z", function() vim.opt.spell = not vim.opt.spell:get(); load_spell_file() end)

-- for configs
map_key("n", "<leader>ne", "<cmd>edit $MYVIMRC<cr>")
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

------------------------------------------------------------------------------------------------------------------------------
-- => nvimtree.1, see after pluging section
------------------------------------------------------------------------------------------------------------------------------
map_key("n", "<leader>e", "<cmd>NvimTreeToggle<cr>")
map_key("n", "<leader>ef", "<cmd>NvimTreeFindFile<cr>")
vim.g.nvim_tree_auto_ignore_ft = { 'startify', 'dashboard' } --empty by default, don't auto open tree on specific filetypes.
vim.g.nvim_tree_quit_on_open = 1 --0 by default, closes the tree when you open a file
vim.g.nvim_tree_indent_markers = 1 --0 by default, this option shows indent markers when folders are open=true
vim.g.nvim_tree_add_trailing = 1 --0 by default, append a trailing slash to folder names
vim.g.nvim_tree_group_empty = 1 -- 0 by default, compact folders that only contain a single folder into one node in the file tree
vim.g.nvim_tree_special_files = { ['README.md']= true, Makefile= true, MAKEFILE= true, Config= true, ['build.gradle']= true, ['.vimspector.json']= true } -- List of filenames that gets highlighted with NvimTreeSpecialFile

------------------------------------------------------------------------------------------------------------------------------
-- => Vimspector.1, see below for autocommands
------------------------------------------------------------------------------------------------------------------------------

-- for normal mode - the word under the cursor
map_key("n", "<Bslash>e", "<Plug>VimspectorBalloonEval")
-- for visual mode, the visually selected text
map_key("x", "<Bslash>e", "<Plug>VimspectorBalloonEval")

map_key("n", "<Bslash>c",        "<Plug>VimspectorContinue")
map_key("n", "<Bslash>l",        "<Plug>VimspectorLaunch")
map_key("n", "<Bslash>t",        "<Plug>VimspectorStop")
map_key("n", "<Bslash>r",        "<Plug>VimspectorRestart")
map_key("n", "<Bslash>p",        "<Plug>VimspectorPause")
map_key("n", "<Bslash>b",        "<Plug>VimspectorToggleBreakpoint")
map_key("n", "<Bslash>bc",       "<Plug>VimspectorToggleConditionalBreakpoint")
map_key("n", "<Bslash>bf",       "<Plug>VimspectorAddFunctionBreakpoint")
map_key("n", "<Bslash>br",       "<Plug>VimspectorRunToCursor")
map_key("n", "<Bslash>bda",      "<cmd>call vimspector#ClearBreakpoints()<cr>")
map_key("n", "<Bslash>s",        "<Plug>VimspectorStepOver")
map_key("n", "<Bslash>i",        "<Plug>VimspectorStepInto")
map_key("n", "<Bslash>o",        "<Plug>VimspectorStepOut")
map_key("n", "<Bslash>d",        "<cmd>VimspectorReset<cr>")

------------------------------------------------------------------------------------------------------------------------------
-- => Plugins
------------------------------------------------------------------------------------------------------------------------------
local Plug = vim.fn['plug#']
vim.fn['plug#begin']('~/.vim/plugged')

Plug 'kyazdani42/nvim-web-devicons' -- Recommended (for coloured icons)

-- language server
Plug 'neovim/nvim-lspconfig'
Plug 'williamboman/nvim-lsp-installer'
-- current function/lsp status
Plug 'nvim-lua/lsp-status.nvim'
-- icons
Plug 'onsails/lspkind-nvim'
-- signature help for functions lsp
Plug 'ray-x/lsp_signature.nvim'

Plug('ms-jpq/coq_nvim', {branch= 'coq'})
Plug('ms-jpq/coq.artifacts', {branch= 'artifacts'})
Plug('ms-jpq/coq.thirdparty', {branch= '3p'})

-- java lsp client
Plug 'mfussenegger/nvim-jdtls'

-- bufferline line
Plug 'romgrk/barbar.nvim'

-- debugging
Plug 'puremourning/vimspector'

-- files search
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-ui-select.nvim'

Plug 'tpope/vim-fugitive'

-- start screen
Plug 'mhinz/vim-startify'

-- commenting
Plug 'b3nj5m1n/kommentary'

-- file explorer
Plug 'kyazdani42/nvim-tree.lua'

Plug 'jackguo380/vim-lsp-cxx-highlight'

-- theme
Plug 'morhetz/gruvbox'
Plug 'Rigellute/shades-of-purple.vim'
Plug 'folke/tokyonight.nvim'
Plug 'rose-pine/neovim'
Plug 'ishan9299/nvim-solarized-lua'

-- git signs
Plug 'lewis6991/gitsigns.nvim'

-- Focused writting
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'

-- testing framework
Plug 'vim-test/vim-test'

Plug 'lukas-reineke/indent-blankline.nvim'

-- FIXME: once change are upstreamed, change back
Plug('dsych/galaxyline.nvim' , {branch= 'bugfix/diagnostics'})
-- Plug 'glepnir/galaxyline.nvim' , {'branch': 'main'}

Plug 'sindrets/diffview.nvim'

Plug 'justinmk/vim-sneak'
Plug 'tpope/vim-surround'

-- terminal
Plug 'akinsho/nvim-toggleterm.lua'

-- syntax highlights and more
-- We recommend updating the parsers on update
Plug('nvim-treesitter/nvim-treesitter', {['do']= ':TSUpdate'})
-- intelligent comments based on treesitter
Plug 'JoosepAlviste/nvim-ts-context-commentstring'
-- additional text objects
Plug 'nvim-treesitter/nvim-treesitter-textobjects'

-- filetype
Plug 'satabin/hocon-vim'

-- markdown preview
-- depends on https://github.com/charmbracelet/glow
Plug 'ellisonleao/glow.nvim'

-- search and replace inside quickfix window
Plug 'gabrielpoca/replacer.nvim'

-- color guides
-- Plug 'rrethy/vim-hexokinase', { 'do': 'make hexokinase' }
-- coverage guide
Plug 'dsych/blanket.nvim'

-- enhance vim's native spell checker
Plug 'dsych/vim-spell'

vim.fn['plug#end']()


------------------------------------------------------------------------------------------------------------------------------------------------------
-- => vimspector.2, attempt to load vimspector session only AFTER plugin has
-- been loaded
------------------------------------------------------------------------------------------------------------------------------------------------------
function save_vimspector_session()
  if vim.fn.filereadable('./.vimspector.json') then
    vim.api.nvim_command("silent! VimspectorMkSession")
  end
end

function load_vimspector_session()
  if vim.fn.filereadable('./.vimspector.session') then
    vim.api.nvim_command("silent! VimspectorLoadSession")
  end
end

vim.cmd([[
augroup vimspector_session
  autocmd!
  autocmd VimLeave * :lua save_vimspector_session()
  autocmd VimEnter * :lua load_vimspector_session()
augroup END
]])
----------------------------------------------------------------------------------------------------------------------------
-- => treesitter text objects
----------------------------------------------------------------------------------------------------------------------------
require'nvim-treesitter.configs'.setup {
    textobjects = {
        select = {
            enable = true,

            -- Automatically jump forward to textobj, similar to targets.vim
            lookahead = true,

            keymaps = {
                -- You can use the capture groups defined in textobjects.scm
                ["af"] = "@function.outer",
                ["if"] = "@function.inner",
                ["ac"] = "@class.outer",
                ["ic"] = "@class.inner",
                ["ia"] = "@parameter.inner",
                ["aa"] = "@parameter.outer",
            },
        },
        move = {
            enable = true,
            set_jumps = true, -- whether to set jumps in the jumplist
            goto_next_start = {
                ["]m"] = "@function.outer",
                ["]]"] = "@class.outer",
                ["]a"] = "@parameter.inner"
            },
            goto_previous_start = {
                ["[m"] = "@function.outer",
                ["[["] = "@class.outer",
                ["[a"] = "@parameter.inner"
            },
        },
    },
}

----------------------------------------------------------------------------------------------------------------------------
-- => kommentary
----------------------------------------------------------------------------------------------------------------------------
require('kommentary.config').configure_language('default', {
  prefer_single_line_comments = true
})
require('kommentary.config').configure_language({'typescriptreact', 'html', 'typescript', 'javascript', 'lua'}, {
  single_line_comment_string = 'auto',
  multi_line_comment_strings = 'auto',
  hook_function = function()
    require('ts_context_commentstring.internal').update_commentstring()
  end,
})

----------------------------------------------------------------------------------------------------------------------------
-- => native lsp and coq
----------------------------------------------------------------------------------------------------------------------------
vim.g.coq_settings = {
    auto_start= "shut-up",
    ['display.icons.mode']= 'short',
    ['display.icons.mappings']= require'lspkind'.presets.default,
    ['keymap.jump_to_mark']= '<C-S>'
}

local show_documentation = function()
  if vim.tbl_contains({ 'vim', 'help' }, vim.opt.filetype:get()) then
    vim.api.nvim_command('h '..vim.api.nvim_eval('expand("<cword>")'))
  elseif not vim.tbl_isempty(vim.lsp.buf_get_clients()) then
    vim.lsp.buf.hover()
  else
    vim.api.nvim_command('!'..vim.opt.keywordprg..' '..vim.fn.expand("<cword>"))
  end
end

local coq = require'coq'
local lsp_installer = require("nvim-lsp-installer")
local lsp_status = require'lsp-status'

lsp_status.config{
  diagnostics = false,
  show_filename = false
}


local mk_config = function()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.workspace.configuration = true
  capabilities.textDocument.completion.completionItem.snippetSupport = true

  return {
    flags = {
      allow_incremental_sync = true,
    };
    handlers = {
      ["textDocument/publishDiagnostics"] = vim.lsp.with(
        vim.lsp.diagnostic.on_publish_diagnostics, {
           -- Enable underline, use default values
           underline = true,
           -- Enable virtual text, override spacing to 4
           virtual_text = {
             spacing = 4,
           },
           -- Disable a feature
           update_in_insert = false,
        }
    ),
  };
    capabilities = capabilities;
    on_init = (function(client)
      client.notify('workspace/didChangeConfiguration', { settings = client.config.settings })
    end)
  }
end

local configure_lsp = function(lsp_opts)
  lsp_opts = lsp_opts or {}

  lsp_status.register_progress()

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  map_key('n', 'gD', vim.lsp.buf.declaration)
  map_key('n', 'gd', require"telescope.builtin".lsp_definitions)
  map_key('n', 'gi', require"telescope.builtin".lsp_implementations)
  map_key('n', '<leader>rn', vim.lsp.buf.rename)
  map_key('n', 'grn', vim.lsp.buf.rename)

  map_key('n', 'gs', require"telescope.builtin".lsp_document_symbols)
  map_key('n', 'K', show_documentation)
  map_key('n', '<C-Y>', vim.lsp.buf.signature_help)
  map_key('n', 'gr', require"telescope.builtin".lsp_references)
  map_key('n', '<leader>gr', require"telescope.builtin".lsp_references)
  map_key('n', '<leader>lci', vim.lsp.buf.incoming_calls)
  map_key('n', '<leader>lco', vim.lsp.buf.outgoing_calls)

  map_key('n', '<leader>wa', vim.lsp.buf.add_workspace_folder)
  map_key('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder)
  map_key('n', '<leader>wl', function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end)

  map_key('n', '<leader>a', vim.lsp.buf.code_action)

  map_key('n', '<leader>de', function() require"telescope.builtin".lsp_document_diagnostics({severity = "ERROR"}) end)
  map_key('n', '<leader>dd', function() require"telescope.builtin".lsp_document_diagnostics() end)
  map_key('n', '[d', vim.diagnostic.goto_prev)
  map_key('n', ']d', vim.diagnostic.goto_next)
  map_key('n', '[e', function() vim.diagnostic.goto_prev({severity = "Error"}) end)
  map_key('n', ']e', function() vim.diagnostic.goto_next({severity = "Error"}) end)

  map_key('n', '<M-F>', vim.lsp.buf.formatting)
  map_key({ 'v', 'x' }, '<M-F>', vim.lsp.buf.range_formatting)

  local old_on_attach = lsp_opts.on_attach

  lsp_opts.on_attach = function(client, bufnr)
    lsp_status.on_attach(client)

    require"lsp_signature".on_attach({
        hint_prefix = "⇵",
        floating_window = false,
    })

    if old_on_attach then
      old_on_attach(client, bufnr)
    end
    -- vim.api.nvim_exec([[
    --     hi LspReferenceRead cterm=bold ctermbg=red guibg=LightYellow
    --     hi LspReferenceText cterm=bold ctermbg=red guibg=LightYellow
    --     hi LspReferenceWrite cterm=bold ctermbg=red guibg=LightYellow
    --     augroup lsp_document_highlight
    --       autocmd!
    --       autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
    --       autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
    --     augroup END
    -- ]], false)
  end

  return coq.lsp_ensure_capabilities(lsp_opts)
end

local server_configs = {
  ["sumneko_lua"] = function()
    local runtime_path = vim.split(package.path, ';')
    table.insert(runtime_path, "lua/?.lua")
    table.insert(runtime_path, "lua/?/init.lua")

    return {
        settings = {
            Lua = {
              runtime = {
                version = "LuaJIT"
              },
              diagnostics = {
                -- Get the language server to recognize the 'vim', 'use' global
                globals = {'vim', 'use'},
              },
              workspace = {
                -- Make the server aware of Neovim runtime files
                library = vim.api.nvim_get_runtime_file("", true)
              },
              -- Do not send telemetry data containing a randomized but unique identifier
              telemetry = {
                enable = false,
              },
            },
        }
    }
  end
}

-- actually start the languare server
lsp_installer.on_server_ready(function(server)
  local config = vim.tbl_deep_extend("force", mk_config(), server_configs[server.name] and server_configs[server.name]() or {})
  server:setup(configure_lsp(config))
end)

local run_checkstyle = function()
  -- record the pwd before changing
  local cwd = vim.fn.getcwd()

  -- get pacakge directory of the current file,
  -- so that we don't need to change the directory manually
  local package_path = vim.fn.fnamemodify(vim.fn.findfile("Config", "./;~"), ":p:h")
  vim.api.nvim_command('cd '..package_path)

  -- checkstyle error format
  vim.opt.makeprg='brazil-build'
  vim.opt.errorformat='[ant:checkstyle]\\ [%.%#]\\ %f:%l:%c:\\ %m,[ant:checkstyle]\\ [%.%#]\\ %f:%l:\\ %m'
  vim.opt.shellpipe='2>&1\\ \\|\\ tee\\ /tmp/checkstyle-errors.txt\\ \\|\\ grep\\ ERROR\\ &>\\ %s'
  vim.api.nvim_command('make check --rerun-tasks')

  -- go back to the old cwd
  vim.api.nvim_command('cd '..cwd)
end

--------------------------------------------------------------
-- > JAVA SPECIFIC LSP CONFIG
--------------------------------------------------------------

-- DEBUGGINS WITH VIMSPECTOR
local start_vimspector_java = function()
  -- need to start java-debug adapter first and pass it's port to vimspector
  require'jdtls.util'.execute_command({command = 'vscode.java.startDebugSession'}, function(err0, port)
    assert(not err0, vim.inspect(err0))

    vim.fn['vimspector#LaunchWithSettings']({AdapterPort= port, configuration= 'Java Attach' })
  end, 0)
end

local on_java_attach = function(client, bufnr)
  require'jdtls.setup'.add_commands()

  -- Java specific mappings
  map_key("n", "<leader>lc", run_checkstyle)
  map_key("n", "<leader>li", require'jdtls'.organize_imports)
  map_key("v", "<leader>le", "<Esc><Cmd>lua require('jdtls').extract_variable(true)<CR>")
  map_key("n", "<leader>le", "<Cmd>lua require('jdtls').extract_variable()<CR>")
  map_key("v", "<leader>lm", "<Esc><Cmd>lua require('jdtls').extract_method(true)<CR>")
  -- overwrite default vimspector launch mapping
  map_key("n", "<Bslash>l", start_vimspector_java)
  -- require'formatter'.setup{
  --     filetype = {
  --         java = {
  --             function()
  --                 return {
  --                     exe = 'java',
  --                     args = { '-jar', os.getenv('HOME') .. '/.local/jars/google-java-format.jar', vim.api.nvim_buf_get_name(0) },
  --                     stdin = true
  --                 }
  --             end
  --         }
  --     }
  -- }

  -- vim.api.nvim_exec([[
  --   augroup FormatAutogroup
  --     autocmd!
  --     autocmd BufWritePost *.java FormatWrite
  --   augroup end
  -- ]], true)
  -- buf_set_keymap('n', '<leader>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)

end

function setup_java_lsp()

  local root_dir = get_java_root and get_java_root() or require('jdtls.setup').find_root({'gradlew', '.git'})

  local home = os.getenv('HOME')
  -- where eclipse stores runtime files about current project
  local eclipse_workspace = home .. "/.local/share/eclipse/" .. vim.fn.fnamemodify(root_dir, ':p:h:t')

  local ws_folders_lsp = get_java_workspaces and get_java_workspaces(root_dir) or {}
  local ws_folders_jdtls = {}
  for _, ws in ipairs(ws_folders_lsp) do
      table.insert(ws_folders_jdtls, string.format("file://%s", ws))
  end

  local capabilities = vim.lsp.protocol.make_client_capabilities()

  capabilities.workspace.configuration = true
  capabilities.textDocument.completion.completionItem.snippetSupport = true

  local config = mk_config()
  config.settings = {
    -- ['java.format.settings.url'] = home .. "/.config/nvim/language-servers/java-google-formatter.xml",
    -- ['java.format.settings.profile'] = "GoogleStyle",
    java = {
      signatureHelp = { enabled = true },
      contentProvider = { preferred = 'fernflower' },
      completion = {
        favoriteStaticMembers = {
          "org.hamcrest.MatcherAssert.assertThat",
          "org.hamcrest.Matchers.*",
          "org.hamcrest.CoreMatchers.*",
          "org.junit.jupiter.api.Assertions.*",
          "java.util.Objects.requireNonNull",
          "java.util.Objects.requireNonNullElse",
          "org.mockito.Mockito.*"
        }
      },
      sources = {
        organizeImports = {
          starThreshold = 9999,
          staticStarThreshold = 9999
        }
      },
      codeGeneration = {
        toString = {
          template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}"
        }
      }
    }
  }
  config.cmd = {'jdtls', eclipse_workspace}
  config.on_attach = on_java_attach
  -- SUPER IMPORTANT, this will prevent lsp from launching in
  -- every workspaces
  config.root_dir = root_dir

  local extendedClientCapabilities = require'jdtls'.extendedClientCapabilities
  extendedClientCapabilities.resolveAdditionalTextEditsSupport = true
  config.init_options = {
    -- jdtls extensions e.g. debugging
    bundles = {
      home .. "/.local/source/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-0.33.0.jar",
      home .. "/.local/source/vscode-java-decompiler/server/dg.jdt.ls.decompiler.fernflower-0.0.2-201802221740.jar"
    };
    extendedClientCapabilities = extendedClientCapabilities;
    workspaceFolders = ws_folders_jdtls,
  }

  -- start the server
  require('jdtls').start_or_attach(configure_lsp(config))

  -- notify lsp about workspaces
  for _,line in ipairs(ws_folders_lsp) do
      vim.lsp.buf.add_workspace_folder(line)
  end

  vim.api.nvim_add_user_command("CleanJavaWorkspace", ":!rm -rf '" .. eclipse_workspace .. "' <bar> :StopLsp <bar> :StartJavaLsp", {})
  map_key("n", "<leader>lr", "<Cmd>CleanJavaWorkspace<CR>")

end


vim.api.nvim_add_user_command("StopLsp", function() vim.lsp.stop_client(vim.lsp.get_active_clients()) end, {})
vim.api.nvim_add_user_command("StartJavaLsp", setup_java_lsp, {})
map_key("n", "<leader>lj", "<cmd>StartJavaLsp<cr>")

vim.cmd([[
    autocmd FileType java :lua setup_java_lsp()
]])

----------------------------------------------------------------------------------------------------------------------------
-- => replacer
----------------------------------------------------------------------------------------------------------------------------
map_key("n", "<leader>rq", require("replacer").run)

----------------------------------------------------------------------------------------------------------------------------
-- => nvimtree.2
----------------------------------------------------------------------------------------------------------------------------
require'nvim-tree'.setup {
  view = {
    width= 50,
    number = true,
    relativenumber = true
  },

  -- updates the root directory of the tree on `DirChanged` (when your run `:cd` usually)
  update_cwd = true,

  -- update the focused file on `BufEnter`, un-collapses the folders recursively until it finds the file
  update_focused_file = {
    enable = true,
  },

  filters = {
    custom = { '.git', '.cache' }
  },

  diagnostics = {
    enable = true,
    show_on_dirs = true,
    icons = {
      hint = "",
      info = "",
      warning = "",
      error = "",
    }
  }
}

------------------------------------------------------------------------------------------------------------------------------
-- => Indentation highlighting with blankline
------------------------------------------------------------------------------------------------------------------------------
require("indent_blankline").setup {
  space_char_blankline = " ",
  show_current_context = true,
  use_treesitter = true,
  buftype_exclude = {'help', 'nerdtree', 'startify', 'LuaTree', 'Telescope*', 'terminal'},
  show_first_indent_level = false,
  context_patterns = { 'class', 'function', 'method', 'expression', 'statement' }
}


------------------------------------------------------------------------------------------------------------------------------
-- => treesitter config
------------------------------------------------------------------------------------------------------------------------------
require('nvim-treesitter.configs').setup {
  ensure_installed = "maintained",
  indent = {
    enable = true
  },
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false
  },
  context_commenting = {
    enable = true,
    autocmd = false
  }
}

------------------------------------------------------------------------------------------------------------------------------
-- => Terminal toggle config
------------------------------------------------------------------------------------------------------------------------------
require("toggleterm").setup{
  open_mapping = [[<c-\>]]
}
-- turn terminal to normal mode with escape
map_key("t", "<Esc>", "<C-\\><C-n>")
-- start terminal in insert mode
-- and do not show terminal buffers in buffer list
vim.cmd([[
augroup terminal
    autocmd!
    autocmd TermOpen * setlocal nobuflisted
    " au BufEnter * if &buftype == 'terminal' | :startinsert | endif
augroup END
]])

------------------------------------------------------------------------------------------------------------------------------
-- => vim-sneak
------------------------------------------------------------------------------------------------------------------------------
-- remap default keybindings to sneak
map_key("n", "f", "<Plug>Sneak_f")
map_key("n", "F", "<Plug>Sneak_F")
map_key("n", "t", "<Plug>Sneak_t")
map_key("n", "T", "<Plug>Sneak_T")

------------------------------------------------------------------------------------------------------------------------------
-- => git signs and hunks
------------------------------------------------------------------------------------------------------------------------------
require('gitsigns').setup{
    on_attach = function(bufnr)
    local gs = package.loaded.gitsigns

    local function map(mode, l, r, opts)
        opts = opts or {}
        opts.buffer = bufnr
        vim.keymap.set(mode, l, r, opts)
    end

    -- Navigation
    map('n', ']c', "&diff ? ']c' : '<cmd>Gitsigns next_hunk<CR>'", {expr=true})
    map('n', '[c', "&diff ? '[c' : '<cmd>Gitsigns prev_hunk<CR>'", {expr=true})

    -- Actions
    map({'n', 'v'}, '<leader>hs', gs.stage_hunk)
    map({'n', 'v'}, '<leader>hr', gs.reset_hunk)
    map('n', '<leader>hS', gs.stage_buffer)
    map('n', '<leader>hu', gs.undo_stage_hunk)
    map('n', '<leader>hR', gs.reset_buffer)
    map('n', '<leader>hp', gs.preview_hunk)
    map('n', '<leader>hb', function() gs.blame_line{full=true} end)
    map('n', '<leader>ht', gs.toggle_current_line_blame)
    map('n', '<leader>hd', gs.diffthis)
    map('n', '<leader>hD', function() gs.diffthis('~') end)
    map('n', '<leader>htd', gs.toggle_deleted)

    -- Text object
    map({'o', 'x'}, 'ih', ':<C-U>Gitsigns select_hunk<CR>')
    end
}

------------------------------------------------------------------------------------------------------------------------------
-- => revision diff config
------------------------------------------------------------------------------------------------------------------------------
require('diffview').setup()

------------------------------------------------------------------------------------------------------------------------------
-- => telescope fuzzy finder
------------------------------------------------------------------------------------------------------------------------------

-- Find files using Telescope command-line sugar.
require'telescope'.setup {
  defaults = {
    prompt_prefix="🔍"
  },
  pickers = {
    find_files = {
      previewer = false,
      theme = "dropdown",
      path_display={"smart", "shorten"},
      hidden = true
    },
    live_grep = {
      theme = "ivy",
      path_display = {
        shorten = { len = 1, exclude = {1, -1} }
      },
      only_sort_text=true
    },
    buffers = {
      previewer = false,
      theme = "ivy",
      path_display = {
        shorten = { len = 1, exclude = {1, -1} }
      },
    }
  },
  extensions = {
    ["ui-select"] = {
      require("telescope.themes").get_dropdown()
    }
  }
}

-- To get fzf loaded and working with telescope, you need to call
-- load_extension, somewhere after setup function:
require("telescope").load_extension("ui-select")


-- file navigation
map_key("n", "<leader>p", require("telescope.builtin").find_files)
map_key("n", "<leader>bb", require("telescope.builtin").buffers)

-- global search, useful with qf + replacer
map_key("n", "<leader>fg", require("telescope.builtin").live_grep)

-- git helpers
map_key("n", "<leader>vb", function() require("telescope.builtin").git_branches{cwd = vim.fn.fnamemodify(vim.fn.finddir(".git", "./;~"), ":p:h:h")} end)
map_key("n", "<leader>vs", function() require("telescope.builtin").git_stash{cwd = vim.fn.fnamemodify(vim.fn.finddir(".git", "./;~"), ":p:h:h")} end)

-- general pickers
map_key("n", "<leader>gc", require("telescope.builtin").commands)
map_key("n", "<leader>gh", require("telescope.builtin").help_tags)
map_key("n", "<leader>gm", require("telescope.builtin").keymaps)

-- resume prev picker with state
map_key("n", "<leader>rr", require("telescope.builtin").resume)

------------------------------------------------------------------------------------------------------------------------------
-- => bufferline
------------------------------------------------------------------------------------------------------------------------------
vim.g.bufferline = {
    -- Enable/disable animations
    animation = true,

    -- Enable/disable auto-hiding the tab bar when there is a single buffer
    auto_hide = false,

    -- Enable/disable current/total tabpages indicator (top right corner)
    tabpages = true,

    -- Enable/disable close button
    closable = true,

    -- Enables/disable clickable tabs
    --  - left-click: go to buffer
    --  - middle-click: delete buffer
    clickable = true,

    -- Enable/disable icons
    -- if set to 'numbers', will show buffer index in the tabline
    -- if set to 'both', will show buffer index and icons in the tabline
    icons = true,

    -- Sets the icon's highlight group.
    -- If false, will use nvim-web-devicons colors
    icon_custom_colors = false,

    -- Configure icons on the bufferline.
    icon_separator_active = '▎',
    icon_separator_inactive = '▎',
    icon_close_tab = '',
    icon_close_tab_modified = '●',

    -- Sets the maximum padding width with which to surround each tab
    maximum_padding = 4,

    -- If set, the letters for each buffer in buffer-pick mode will be
    -- assigned based on their name. Otherwise or in case all letters are
    -- already assigned, the behavior is to assign letters in order of
    -- usability (see order below)
    semantic_letters = true,

    -- New buffer letters are assigned in this order. This order is
    -- optimal for the qwerty keyboard layout but might need adjustement
    -- for other layouts.
    letters = 'asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP',
}

map_key("n", "<leader>bp", "<cmd>BufferPick<cr>")

-- Close the current buffer
map_key("n", "<leader>bd", "<cmd>BufferClose<cr>")
map_key("n", "<A-l>", "<cmd>BufferNext<cr>")
map_key("n", "<A-h>", "<cmd>BufferPrevious<cr>")
-- Close all the buffers
map_key("n", "<leader>bda", "<cmd>bufdo bd<cr>")

-- Close all buffers but the current one
-- command! BufOnly silent! execute --%bd|e#|db#--
map_key("n", "<leader>bdo", "<cmd>BufferCloseAllButCurrent<cr>")

------------------------------------------------------------------------------------------------------------------------------
-- => vim-test framework for testing
------------------------------------------------------------------------------------------------------------------------------
map_key("n", "<leader>in", "<cmd>execute('TestNearest '.g:test_extra_flags)")
map_key("n", "<leader>if", "<cmd>execute('TestFile '.g:test_extra_flags)")
map_key("n", "<leader>is", "<cmd>execute('TestSuite '.g:test_extra_flags)")
map_key("n", "<leader>il", "<cmd>execute('TestLast '.g:test_extra_flags)")
map_key("n", "<leader>ig", "<cmd>execute('TestVisit '.g:test_extra_flags)")
-- for maven set to something like this:
--  -Dtests.additional.jvmargs=--'-Xdebug -Xrunjdwp:transport=dt_socket,address=localhost:5005,server=y,suspend=y'--
-- for gradle use:
--  --debug-jvm
vim.g.test_debug_flags = ''
vim.g.test_extra_flags = ''
map_key("n", "<leader>idf", function() vim.g.test_debug_flags="" end)
map_key("n", "<leader>ie", function() vim.g.test_debug_flags="" end)
map_key("n", "<leader>id", "<cmd>execute('TestNearest '.g:test_extra_flags.' '.g:test_debug_flags)")
map_key("n", "<leader>ids", "<cmd>execute('TestSuite '.g:test_extra_flags.' '.g:test_debug_flags)")

vim.g['test#strategy'] = 'neovim'

------------------------------------------------------------------------------------------------------------------------------
-- => GoYo and Limeline configuration to define Zen mode
------------------------------------------------------------------------------------------------------------------------------
vim.g.limelight_conceal_ctermfg = 240

local zen_mode=false
local function toggle_zen()
  if zen_mode then
    -- Disable zen mode
    zen_mode = 0
    ToggleRelativeNumbers(true)
    vim.cmd("Goyo!")
    vim.cmd("Limelight!")
  else
    -- Enable zen mode
    zen_mode = true
    ToggleRelativeNumbers(false)
    vim.cmd("Goyo")
    vim.cmd("Limelight")
  end
end
vim.api.nvim_add_user_command("Zen", toggle_zen, {})



------------------------------------------------------------------------------------------------------------------------------
-- => Startify configurations
------------------------------------------------------------------------------------------------------------------------------
-- save current layout into session
map_key("n", "<leader>ss", function() vim.cmd("SSave!") end)

vim.g.startify_session_before_save = { 'echo "Cleaning up before saving.."', 'silent! NvimTreeClose' }

vim.g.startify_session_persistence = true

-- save coc's workspace folders between sessions
vim.g.startify_session_savevars = { 'g:startify_session_savevars', 'g:startify_session_savecmds', 'g:WorkspaceFolders' }

------------------------------------------------------------------------------------------------------------------------------
-- => Rose-pint
------------------------------------------------------------------------------------------------------------------------------
vim.g.rose_pine_variant = 'moon'
vim.g.rose_pine_bold_vertical_split_line = true

------------------------------------------------------------------------------------------------------------------------------
-- => Tokyonight
------------------------------------------------------------------------------------------------------------------------------
-- NOTE: has to precede the color scheme settings
vim.g.tokyonight_style = 'storm'
vim.g.tokyonight_sidebars = { 'nerdtree', 'terminal', 'LuaTree', 'sidebarnvim' }
vim.g.tokyonight_hide_inactive_statusline = true
vim.g.tokyonight_italic_comments = true

vim.cmd([[
augroup file_types
    autocmd!
    autocmd BufRead,BufNewFile *.json set filetype=jsonc
    autocmd BufRead,BufNewFile *sqc,*HPP,*CPP set filetype=cpp
augroup END
]])
------------------------------------------------------------------------------------------------------------------------------
-- => Colors and Fonts
------------------------------------------------------------------------------------------------------------------------------
-- THIS IS PURE FUCKING EVIL!!! DO NOT E-V-E-R SET THIS OPTION
-- screws up all of the terminal colors, completely.
-- going to leave it here is a reminder...
-- OH HOW THINGS HAVE CHANGED)
vim.opt.termguicolors = true

vim.cmd("colorscheme solarized")
vim.cmd("autocmd ColorScheme tokyonight highlight! link LineNr Question")
vim.cmd("autocmd ColorScheme tokyonight highlight! link CursorLineNr Question")
-- Update bracket matching highlight group to something sane that can be read
-- Apparently, there is such a thing as dynamic color scheme, so
-- register an autocomand to make sure that we update the highlight
-- group when color scheme changes
vim.cmd("autocmd ColorScheme shades_of_purple highlight! link MatchParen Search")


-- Enable syntax highlighting
vim.cmd("syntax enable")
vim.g.background="dark"

------------------------------------------------------------------------------------------------------------------------------
-- => Helper functions
------------------------------------------------------------------------------------------------------------------------------
-- too cumbersome to migrate...
vim.cmd([[
function! CmdLine(str)
    call feedkeys(":" . a:str)
endfunction

function! VisualSelection(direction, extra_filter) range
    let l:saved_reg = @"
    execute "normal! vgvy"

    let l:pattern = escape(@", "\\/.*'$^~[]")
    let l:pattern = substitute(l:pattern, "\n$", "", "")

    if a:direction == 'gv'
        call CmdLine("Ack '" . l:pattern . "' " )
    elseif a:direction == 'replace'
        call CmdLine("%s" . '/'. l:pattern . '/')
    endif

    let @/ = l:pattern
    let @" = l:saved_reg
endfunction
]])

vim.cmd([[
let s:spring_boot_active_profile = ""

function! s:start_spring_boot_app_in_debug_mode(is_debug) abort

  let files = split(system('find . -name pom.xml'), '\n')

  if empty(files)
      echo 'Unable to detect spring boot projects'
      return
  endif

  let target_file = inputlist(['Select the target project'] + map(copy(files), 'v:key+1.". ".substitute(substitute(v:val, "\./", "", ""), "/pom.xml", "", "")'))

  if target_file < 1 || target_file >= len(files)
      return
  endif

  let s:spring_boot_active_profile = input("Which profile to use: ", s:spring_boot_active_profile)

  let command = 'mvn spring-boot:run'

  if a:is_debug
    let command +=  ' -Dspring-boot.run.jvmArguments="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=y,address=5005"'
  endif

  botright split term://bash
  call feedkeys(command.' -Dspring-boot.run.profiles='.s:spring_boot_active_profile.' -f '.files[target_file - 1]."\<cr>")

endfunction

command! SpringStartDebug call s:start_spring_boot_app_in_debug_mode(1)
command! SpringStart call s:start_spring_boot_app_in_debug_mode(0)
]])

vim.cmd([[
" redirect the output of a Vim or external command into a scratch buffer
function! Redir(cmd)
  if a:cmd =~ '^!'
    execute "let output = system('" . substitute(a:cmd, '^!', '', '') . "')"
  else
    redir => output
    execute a:cmd
    redir END
  endif
  new
  " setlocal nobuflisted buftype=nofile bufhidden=wipe noswapfile
  call setline(1, split(output, "\n"))
endfunction
command! -nargs=1 Redir silent call Redir(<f-args>)
]])


------------------------------------------------------------------------------
-- Evil line configuration for galaxyline
------------------------------------------------------------------------------
local gl = require('galaxyline')
local gls = gl.section
local extension = require('galaxyline.provider_extensions')
local condition = require('galaxyline.condition')
local diag = require('galaxyline.provider_diagnostic')
local fileinfo = require('galaxyline.provider_fileinfo')

gl.short_line_list = {
    'LuaTree',
    'vista',
    'dbui',
    'startify',
    'term',
    'nerdtree',
    'fugitive',
    'fugitiveblame',
    'plug'
}

local icons = {
  rounded_left_filled = '',
  rounded_right_filled = '',
  arrow_left_filled = '', -- e0b2
  arrow_right_filled = '', -- e0b0
  arrow_left = '', -- e0b3
  arrow_right = '', -- e0b1
  ghost = '',
  warn = '',
  info = '',
  error = '',
  hint = '',
  branch = '',
  dotdotdot = '…',
  line_number = '',
}

-- local theme_colors = require'solarized.colors'.getColors()
local theme_colors = {
	none = 'none',
	base02  = '#073642',
	red     = '#dc322f',
	green   = '#859900',
	yellow  = '#b58900',
	blue    = '#268bd2',
	magenta = '#d33682',
	cyan    = '#2aa198',
	base2   = '#eee8d5',
	base03  = '#002b36',
	back    = '#002b36',
	orange  = '#cb4b16',
	base01  = '#586e75',
	base00  = '#657b83',
	base0   = '#839496',
	violet  = '#6c71c4',
	base1   = '#93a1a1',
	base3   = '#fdf6e3',
	err_bg  = '#fdf6e3'
}
local color_overrides = {
    bg = theme_colors.base02,
}

local colors = vim.tbl_deep_extend('force', theme_colors, color_overrides)

local get_mode = function()
  local mode_colors = {
    [110] = { 'NORMAL', colors.blue, colors.bg },
    [105] = { 'INSERT', colors.cyan, colors.bg },
    [99] = { 'COMMAND', colors.orange, colors.bg },
    [116] = { 'TERMINAL', colors.blue, colors.bg },
    [118] = { 'VISUAL', colors.violet, colors.bg },
    [22] = { 'V-BLOCK', colors.violet, colors.bg },
    [86] = { 'V-LINE', colors.violet, colors.bg },
    [82] = { 'REPLACE', colors.red, colors.bg },
    [115] = { 'SELECT', colors.red, colors.bg },
    [83] = { 'S-LINE', colors.red, colors.bg },
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
  if gui ~= nil and gui ~= '' then
    vim.api.nvim_command(('hi %s guibg=%s guifg=%s gui=%s'):format(group, bg, fg, gui))
  elseif bg == nil then
    vim.api.nvim_command(('hi %s guifg=%s'):format(group, fg))
  else
    vim.api.nvim_command(('hi %s guibg=%s guifg=%s'):format(group, bg, fg))
  end
end

local function trailing_whitespace()
    local trail = vim.fn.search("\\s$", "nw")
    if trail ~= 0 then
        return ' '
    else
        return nil
    end
end

TrailingWhiteSpace = trailing_whitespace

function has_file_type()
    local f_type = vim.bo.filetype
    if not f_type or f_type == '' then
        return false
    end
    return true
end

local buffer_not_empty = function()
  if vim.fn.empty(vim.fn.expand('%:t')) ~= 1 then
    return true
  end
  return false
end

local function split(str, sep)
  local res = {}
  for w in str:gmatch('([^' .. sep .. ']*)') do
    if w ~= '' then
      table.insert(res, w)
    end
  end
  return res
end

local FilePathShortProvider = function()
  local fp = vim.fn.fnamemodify(vim.fn.expand('%'), ':~:.:h')
  local tbl = split(fp, '/')
  local len = #tbl

  if len > 2 and tbl[1] ~= '~' then
    return icons.dotdotdot .. '/' .. table.concat(tbl, '/', len - 1) .. '/'
  else
    return fp .. '/'
  end
end

local checkwidth = function()
  local squeeze_width  = vim.fn.winwidth(0) / 2
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

    if result ~= nil and result ~= '' then
      return icon
    end
  end
end

gls.left = {
  {
    GhostLeftBracket = {
      provider = BracketProvider(icons.rounded_left_filled, true),
      highlight = 'GalaxyViModeNestedInv',
    },
  },
  {
    Ghost = {
      provider = BracketProvider(icons.ghost, true),
      highlight = 'GalaxyViModeInv',
    },
  },
  {
    ViModeLeftBracket = {
      provider = BracketProvider(icons.rounded_right_filled, true),
      highlight = 'GalaxyViMode',
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
        highlight('GalaxyViMode', mode_color, mode_nested)
        highlight('GalaxyViModeInv', mode_nested, mode_color)
        highlight('GalaxyViModeNested', mode_nested, colors.bg)
        highlight('GalaxyViModeNestedInv', colors.bg, mode_nested)
        highlight('GalaxyPercentBracket', colors.bg, mode_color)

        highlight('GalaxyGitLCBracket', mode_nested, mode_color)

        if condition.buffer_not_empty() then
          highlight('GalaxyViModeBracket', mode_nested, mode_color)
        else
          if condition.check_git_workspace() then
            highlight('GalaxyGitLCBracket', colors.bg, mode_color)
          end
          highlight('GalaxyViModeBracket', colors.bg, mode_color)
        end
        return '  ' .. label .. ' '
      end,
    },
  },
   {
    ViModeBracket = {
      provider = BracketProvider(icons.arrow_right_filled, true),
      highlight = 'GalaxyViModeBracket',
    },
  },
  {
    GitIcon = {
      provider = BracketProvider('  ' .. icons.branch .. ' ', true),
      condition = check_width_and_git_and_buffer,
      highlight = 'GalaxyViModeInv',
    },
  },
  {
    GitBranch = {
      provider = function()
        local vcs = require('galaxyline.provider_vcs')
        local branch_name = vcs.get_git_branch()
        if not branch_name then
          return ' no git '
        end
        if string.len(branch_name) > 28 then
          return string.sub(branch_name, 1, 25) .. icons.dotdotdot
        end
        return branch_name .. ' '
      end,
      condition = check_width_and_git_and_buffer,
      highlight = 'GalaxyViModeInv',
      separator = icons.arrow_right,
      separator_highlight = 'GalaxyViModeInv',
    },
  },
  {
    FileIcon = {
      provider = function()
        local icon = fileinfo.get_file_icon()
        if condition.check_git_workspace() then
          return ' ' .. icon
        end

        return '  ' .. icon
      end,
      condition = condition.buffer_not_empty,
      highlight = 'GalaxyViModeInv',
    },
  },
  {
    FilePath = {
      provider = FilePathShortProvider,
      condition = check_buffer_and_width,
      highlight = 'GalaxyViModeInv',
    },
  },
  {
    FileName = {
      provider = 'FileName',
      condition = condition.buffer_not_empty,
      highlight = 'GalaxyViModeInv',
      separator = icons.arrow_right_filled,
      separator_highlight = 'GalaxyViModeNestedInv',
    },
  },
  {
    DiffAdd = {
      provider = 'DiffAdd',
      condition = checkwidth,
      icon = ' ',
      highlight = {colors.green,colors.bg},
    }
  },
  {
    DiffModified = {
      provider = 'DiffModified',
      condition = checkwidth,
      icon = ' ',
      highlight = {colors.orange,colors.bg},
    }
  },
  {
    DiffRemove = {
      provider = 'DiffRemove',
      condition = checkwidth,
      icon = ' ',
      highlight = {colors.red,colors.bg},
    }
  },
  {
    LspStatus = {
      provider = {
        BracketProvider(icons.arrow_right, true),
        function()
          return require'lsp-status'.status()
        end
      },
      highlight = 'GalaxyViModeInv',
    }
  }
}

highlight('GalaxyDiagnosticError', colors.red, colors.bg)
highlight('GalaxyDiagnosticErrorInv', colors.bg, colors.red)

highlight('GalaxyDiagnosticWarn', colors.yellow, colors.bg)
highlight('GalaxyDiagnosticWarnInv', colors.bg, colors.yellow)

highlight('GalaxyDiagnosticInfo', colors.violet, colors.bg)
highlight('GalaxyDiagnosticInfoInv', colors.bg, colors.violet)

local LineColumnProvider = function()
  local line_column = fileinfo.line_column()
  line_column = line_column:gsub('%s+', '')
  return ' ' .. icons.line_number .. line_column
end

local PercentProvider = function()
  local line_column = fileinfo.current_line_percent()
  line_column = line_column:gsub('%s+', '')
  return line_column .. ' ☰'
end

gls.right = {
  {
    DiagnosticErrorLeftBracket = {
      provider = BracketProvider(icons.rounded_left_filled, diag.get_diagnostic_error),
      highlight = 'GalaxyDiagnosticErrorInv',
      condition = condition.buffer_not_empty,
    },
  },
{
    DiagnosticError = {
      provider = 'DiagnosticError',
      icon = icons.error .. ' ',
      highlight = 'GalaxyDiagnosticError',
      condition = condition.buffer_not_empty,
    },
  },
  {
    DiagnosticErrorRightBracket = {
      provider = {
        BracketProvider(icons.rounded_right_filled, diag.get_diagnostic_error),
        BracketProvider(' ', diag.get_diagnostic_error),
      },
      highlight = 'GalaxyDiagnosticErrorInv',
      condition = condition.buffer_not_empty,
    },
  },
  {
    DiagnosticWarnLeftBracket = {
      provider = BracketProvider(icons.rounded_left_filled, diag.get_diagnostic_warn),
      highlight = 'GalaxyDiagnosticWarnInv',
      condition = condition.buffer_not_empty,
    },
  },
  {
    DiagnosticWarn = {
      provider = 'DiagnosticWarn',
      highlight = 'GalaxyDiagnosticWarn',
      icon = icons.warn .. ' ',
      condition = condition.buffer_not_empty,
    },
  },
  {
    DiagnosticWarnRightBracket = {
      provider = {
        BracketProvider(icons.rounded_right_filled, diag.get_diagnostic_warn),
        BracketProvider(' ', diag.get_diagnostic_warn),
      },
      highlight = 'GalaxyDiagnosticWarnInv',
      condition = condition.buffer_not_empty,
    },
  },
  {
    DiagnosticInfoLeftBracket = {
      provider = BracketProvider(icons.rounded_left_filled, diag.get_diagnostic_info),
      highlight = 'GalaxyDiagnosticInfoInv',
    },
  },
  {
    DiagnosticInfo = {
      provider = 'DiagnosticInfo',
      icon = icons.info .. ' ',
      highlight = 'GalaxyDiagnosticInfo',
      condition = check_width_and_git_and_buffer,
    },
  },
  {
    DiagnosticInfoRightBracket = {
      provider = {
        BracketProvider(icons.rounded_right_filled, diag.get_diagnostic_info),
        BracketProvider(' ', diag.get_diagnostic_info),
      },
      highlight = 'GalaxyDiagnosticInfoInv',
      condition = condition.buffer_not_empty,
    },
  },
  {
    LineColumn = {
      provider = {
        LineColumnProvider,
        function()
          return ' '
        end,
      },
      highlight = 'GalaxyViMode',
      separator = icons.arrow_left_filled,
      separator_highlight = 'GalaxyGitLCBracket',
    },
  },
  {
    PerCent = {
      provider = {
        PercentProvider,
      },
      highlight = 'GalaxyViMode',
      separator = icons.arrow_left .. ' ',
      separator_highlight = 'GalaxyViModeLeftBracket',
    },
  },
  {
    PercentRightBracket = {
      provider = BracketProvider(icons.rounded_right_filled, true),
      highlight = 'GalaxyPercentBracket',
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
          return '  '
        end,
        'FileIcon',
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
      provider = 'FileName',
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
          return ' '
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
      separator = icons.arrow_left .. ' ',
      highlight = { colors.base3, colors.bg },
    },
  },
}

-- ------------------------------------------------------
--  Additional runtime path and script locations
-- ------------------------------------------------------

-- source any additional configuration files that i don't want to check in git
source_all_additional_files(vim.fn.stdpath('config')..'/additional')
vim.opt.runtimepath:append("$HOME/.config/nvim/additional")

