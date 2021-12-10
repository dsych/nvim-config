"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => GLOBAL OVERLOADS
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:source_all_additional_files(dir_path) abort
  if isdirectory(a:dir_path)
      for d in readdir(a:dir_path, {n -> n =~ '.vim'})
        let filename = a:dir_path.'/'.d
        if filereadable(filename)
            call execute('source '.filename)
        endif
      endfor
  endif
endfunction

" load host specific configuration here
call s:source_all_additional_files(stdpath('config').'/additional/host')

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => General
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if has('win32') || has('win64')
  " if has_key(environ(), 'GIT_BASH')
    " let &shell = environ()['GIT_BASH']
  " else
  let &shell='cmd.exe'
  " endif
endif
" increase timeout between keys
set timeoutlen=1500

" Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
" delays and poor user experience.
set updatetime=300

" TextEdit might fail if hidden is not set.
set hidden

" Some servers have issues with backup files
set nobackup
set nowritebackup

" Give more space for displaying messages.
set cmdheight=2

" Don't pass messages to |ins-completion-menu|.
set shortmess+=c

" persist global variables inside session, so that workspace folders are saved
" between sessions
" set sessionoptions+=globals

" Always show the signcolumn, otherwise it would shift the text each time
" diagnostics appear/become resolved.
set signcolumn=yes:2

" remap leader to space
nnoremap <space> <Nop>
let mapleader=" "

" Sets how many lines of history VIM has to remember
set history=500

nnoremap <silent> <leader>z  :stop<cr>

" escape insert mode with jk
imap <silent> jk <esc>

" copy and paste from/to the system clipboard
" map <silent> <leader><c-p> "+p<cr>
" map <silent> <leader><c-y> "+y<cr>

" quickly saving with <leader>
map <silent> <leader>w :write<cr>
map <silent> <leader>q :quit<cr>

" Necessary  for lots of cool vim things
set nocompatible

" This shows what you are typing as a command.  I love this!
set showcmd

" automatically reload the current buffer if an external program modified it
set autoread

" highlight the current line
set cursorline

" disable line wrapping
set nowrap

" save and source vimrc
" map <leader>vims :write | so $MYVIMRC


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => VIM user interface
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Set 7 lines to the cursor - when moving vertically using j/k
set so=7

" Turn on the Wild menu, command completion in the command mode
set wildmenu

" Ignore compiled files
set wildignore=*.o,*~,*.pyc
if has("win16") || has("win32")
    set wildignore+=.git\*,.hg\*,.svn\*
else
    set wildignore+=*/.git/*,*/.hg/*,*/.svn/*,*/.DS_Store
endif

"Always show current position
set ruler

" Disable mouse for all modes
set mouse=

" Configure backspace so it acts as it should act
set backspace=eol,start,indent
set whichwrap+=<,>,h,l

" Ignore case when searching
set ignorecase

" When searching try to be smart about cases
set smartcase

" Highlight search results
set hlsearch

" Makes search act like search in modern browsers
set incsearch

" Don't redraw while executing macros (good performance config)
" set lazyredraw

" For regular expressions turn magic on
set magic

" Show matching brackets when text indicator is over them
set showmatch
" How many tenths of a second to blink when matching brackets
set mat=2

" No annoying sound on errors
set noerrorbells
set novisualbell
set t_vb=
set tm=500

" Add a bit extra margin to the left
" set foldcolumn=1

" set relative line numbers
set number relativenumber
"
" toggle to absolute line numbers in insert mode and when buffer loses focus
function! ToggleRelativeNumbers(mode)
  if a:mode
    augroup numbertoggle
      autocmd!
      autocmd BufEnter,FocusGained,InsertLeave * set relativenumber
      autocmd BufLeave,FocusLost,InsertEnter   * set norelativenumber
    augroup END
  else
    augroup numbertoggle
      autocmd!
    augroup END
  endif
endfunction

call ToggleRelativeNumbers(1)

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Text, tab and indent related
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Use spaces instead of tabs
set expandtab

" set indent width
set tabstop=4

" set configure << and >> to be the same number of spaces as tabstop
set shiftwidth=0

" Be smart when using tabs ;)
set smarttab

""""""""""""""""""""""""""""""
" => Visual mode related
""""""""""""""""""""""""""""""
" Visual mode pressing * or # searches for the current selection
" Super useful! From an idea by Michael Naumann
vnoremap <silent> * :<C-u>call VisualSelection('', '')<CR>/<C-R>=@/<CR><CR>
vnoremap <silent> # :<C-u>call VisualSelection('', '')<CR>?<C-R>=@/<CR><CR>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Moving around, tabs, windows and buffers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Disable highlight when <leader><cr> is pressed
map <silent> <leader><cr> :noh<cr>

" Smart way to move between windows
map <C-j> <C-W>j
map <C-k> <C-W>k
map <C-h> <C-W>h
map <C-l> <C-W>l


" Useful mappings for managing tabs
map <silent> <leader>tn :tabnew<cr>
map <silent> <leader>to :tabonly<cr>
map <silent> <leader>td :tabclose<cr>
map <silent> <leader>tm :tabmove
map <silent> <leader>t<leader> :tabnext<cr>
" Opens a new tab with the current buffer's path
" Super useful when editing files in the same directory
map <leader>te :tabedit <C-r>=expand("%:p:h")<cr>/

" Let 'tl' toggle between this and the last accessed tab
let g:lasttab = 1
nmap <Leader>tl :exe "tabn ".g:lasttab<CR>
au TabLeave * let g:lasttab = tabpagenr()

" Switch CWD to the directory of the open buffer
map <leader>cd :cd %:p:h<cr>:pwd<cr>

" Return to last edit position when opening files (You want this!)
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

""""""""""""""""""""""""""""""
" => Status line
""""""""""""""""""""""""""""""
" Always show the status line
set laststatus=2

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Editing mappings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Remap VIM 0 to first non-blank character
map 0 ^

" Move a line of text using ALT+[jk] or Command+[jk] on mac
nmap <M-j> mz:m+<cr>`z
nmap <M-k> mz:m-2<cr>`z
vmap <M-j> :m'>+<cr>`<my`>mzgv`yo`z
vmap <M-k> :m'<-2<cr>`>my`<mzgv`yo`z

" Delete trailing white space on save, useful for some filetypes ;)
fun! CleanExtraSpaces()
    let save_cursor = getpos(".")
    let old_query = getreg('/')
    silent! %s/\s\+$//e
    call setpos('.', save_cursor)
    call setreg('/', old_query)
endfun

autocmd BufWritePre * :call CleanExtraSpaces()

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => convenience mappings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
augroup git_commit
    autocmd!
    autocmd FileType gitcommit :set spell
augroup end

nnoremap <silent> <leader>z :set spell!<cr>

" for configs
nnoremap <leader>ne :edit $MYVIMRC<cr>
nnoremap <leader>na :tabnew <bar> :edit ~/.config/nvim/additional<cr>

" insert mode deletion
inoremap <M-l> <del>
inoremap <M-h> <bs>

" pre/a-ppend line without moving cursor
nnoremap <silent> <leader>o :<C-u>call append(line("."),   repeat([""], v:count1))<CR>
nnoremap <silent> <leader>O :<C-u>call append(line(".")-1, repeat([""], v:count1))<CR>

" navigate quickfix with ease
nnoremap ]q :cnext<cr>
nnoremap [q :cprev<cr>
nnoremap qo :copen<cr>
nnoremap qc :cclose<cr>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Command mode related
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Bash like keys for the command line
cnoremap <C-A>		<Home>
cnoremap <C-E>		<End>
cnoremap <C-K>		<C-U>

cnoremap <C-P> <Up>
cnoremap <C-N> <Down>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => nvimtree.1, see after pluging section
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
map <silent> <leader>e :NvimTreeToggle<cr>
map <silent> <leader>ef :NvimTreeFindFile<cr>
let g:nvim_tree_auto_ignore_ft = [ 'startify', 'dashboard' ] "empty by default, don't auto open tree on specific filetypes.
let g:nvim_tree_quit_on_open = 1 "0 by default, closes the tree when you open a file
let g:nvim_tree_indent_markers = 1 "0 by default, this option shows indent markers when folders are open
let g:nvim_tree_add_trailing = 1 "0 by default, append a trailing slash to folder names
let g:nvim_tree_group_empty = 1 " 0 by default, compact folders that only contain a single folder into one node in the file tree
let g:nvim_tree_special_files = { 'README.md': 1, 'Makefile': 1, 'MAKEFILE': 1, 'Config': 1, 'build.gradle': 1, '.vimspector.json': 1 } " List of filenames that gets highlighted with NvimTreeSpecialFile

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Vimspector
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" for normal mode - the word under the cursor
nmap <Bslash>e <Plug>VimspectorBalloonEval
" for visual mode, the visually selected text
xmap <Bslash>e <Plug>VimspectorBalloonEval

nmap <Bslash>c        <Plug>VimspectorContinue
nmap <Bslash>l        <Plug>VimspectorLaunch
nmap <Bslash>t        <Plug>VimspectorStop
nmap <Bslash>r        <Plug>VimspectorRestart
nmap <Bslash>p        <Plug>VimspectorPause
nmap <Bslash>b        <Plug>VimspectorToggleBreakpoint
nmap <Bslash>bc       <Plug>VimspectorToggleConditionalBreakpoint
nmap <Bslash>bf       <Plug>VimspectorAddFunctionBreakpoint
nmap <Bslash>br       <Plug>VimspectorRunToCursor
nmap <Bslash>bda      :call vimspector#ClearBreakpoints()<cr>
nmap <Bslash>s        <Plug>VimspectorStepOver
nmap <Bslash>i        <Plug>VimspectorStepInto
nmap <Bslash>o        <Plug>VimspectorStepOut
nmap <Bslash>d        :VimspectorReset<cr>

function! s:save_vimspector_session() abort
  if filereadable('./.vimspector.json')
    execute VimspectorMkSession
  endif
endfunction

function! s:load_vimspector_session() abort
  if filereadable('./.vimspector.session')
    execute VimspectorLoadSession
  endif
endfunction

augroup vimspector_session
  autocmd!
  autocmd VimLeave * :call s:save_vimspector_session()
  autocmd VimEnter * :call s:load_vimspector_session()
augroup END

function! s:Debugpy() abort
  py3 __import__( 'vimspector',
                \ fromlist=[ 'developer' ] ).developer.SetUpDebugpy()
endfunction

" add command to allow debugging of vimspector with vimspector...
command! -nargs=0 Debugpy call s:Debugpy()

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Plugins
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
call plug#begin('~/.vim/plugged')

Plug 'kyazdani42/nvim-web-devicons' " Recommended (for coloured icons)

" language server
Plug 'neovim/nvim-lspconfig'
Plug 'williamboman/nvim-lsp-installer'
Plug 'nvim-lua/lsp-status.nvim'
Plug 'onsails/lspkind-nvim'

Plug 'ms-jpq/coq_nvim', {'branch': 'coq'}
Plug 'ms-jpq/coq.artifacts', {'branch': 'artifacts'}
Plug 'ms-jpq/coq.thirdparty', {'branch': '3p'}

Plug 'mfussenegger/nvim-jdtls'

" bufferline line
Plug 'romgrk/barbar.nvim'

" debugging
Plug 'puremourning/vimspector'

" files search
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'

Plug 'tpope/vim-fugitive'

" start screen
Plug 'mhinz/vim-startify'

" commenting
Plug 'b3nj5m1n/kommentary'

" file explorer
Plug 'kyazdani42/nvim-tree.lua'

" file indentation detection
" Plug 'tpope/vim-sleuth'

Plug 'neoclide/jsonc.vim'

Plug 'jackguo380/vim-lsp-cxx-highlight'

" theme
Plug 'morhetz/gruvbox'
Plug 'Rigellute/shades-of-purple.vim'
Plug 'folke/tokyonight.nvim'
Plug 'rose-pine/neovim'

" git signs
Plug 'lewis6991/gitsigns.nvim'

" Focused writting
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'

" testing framework
Plug 'vim-test/vim-test'

Plug 'lukas-reineke/indent-blankline.nvim'

" register management
" Plug 'tversteeg/registers.nvim'

Plug 'glepnir/galaxyline.nvim' , {'branch': 'main'}

Plug 'sindrets/diffview.nvim'

Plug 'justinmk/vim-sneak'
Plug 'tpope/vim-surround'

" terminal
Plug 'akinsho/nvim-toggleterm.lua'

" syntax highlights and more
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}  " We recommend updating the parsers on update
" intelligent comments based on treesitter
Plug 'JoosepAlviste/nvim-ts-context-commentstring'
" additional text objects
Plug 'nvim-treesitter/nvim-treesitter-textobjects'

" style checker
" Plug 'vim-syntastic/syntastic'

Plug 'satabin/hocon-vim'

" markdown preview
" depends on https://github.com/charmbracelet/glow
Plug 'ellisonleao/glow.nvim'

" search and replace inside quickfix window
Plug 'gabrielpoca/replacer.nvim'

" improved text objects
Plug 'wellle/targets.vim'

Plug 'dsych/solarized.nvim', {'branch': 'feature/additional_plugins'}

call plug#end()
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => treesitter text objects
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
lua <<EOF
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
        ["ii"] = "@conditional.inner",
        ["ai"] = "@conditional.outer"
      },
    }
  }
}
EOF

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => kommentary
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
lua << EOF
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
EOF

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => native lsp and coq
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:coq_settings = {
    \ 'auto_start': "shut-up",
    \ 'display.icons.mode': 'short',
    \ 'display.icons.mappings': luaeval("require'lspkind'.presets.default"),
    \ 'keymap.jump_to_mark': '<C-S>'
\ }

lua <<EOF
local is_inside = function(target, src)
  for i,v in ipairs(src) do
    if v == target then
      return true
    end
  end
  return false
end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

show_documentation = function()
  if is_inside(vim.api.nvim_buf_get_option(0, 'filetype'), { 'vim', 'help' }) then
    vim.api.nvim_command('h '..vim.api.nvim_eval('expand("<cword>")'))
  elseif not vim.tbl_isempty(vim.lsp.buf_get_clients()) then
    vim.lsp.buf.hover()
  else
    vim.api.nvim_command('!'..vim.api.nvim_eval('"&keywordprg"')..' '..vim.api.nvim_eval('expand("<cword>")'))
  end
end

local coq = require'coq'
local lsp_installer = require("nvim-lsp-installer")
local lsp_status = require'lsp-status'

lsp_status.config{
  diagnostics = false,
  show_filename = false
}


-- Mappings.
local function buf_set_keymap(...) vim.api.nvim_set_keymap(...) end
local keymap_opts = { noremap=true, silent=true }

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
  buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', keymap_opts)
  buf_set_keymap('n', 'gd', '<cmd>lua require"telescope.builtin".lsp_definitions()<CR>', keymap_opts)
  buf_set_keymap('n', 'gi', '<cmd>lua require"telescope.builtin".lsp_implementations()<CR>', keymap_opts)
  buf_set_keymap('n', '<leader>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', keymap_opts)
  buf_set_keymap('n', 'grn', '<cmd>lua vim.lsp.buf.rename()<CR>', keymap_opts)

  buf_set_keymap('n', 'gs', '<cmd>lua require"telescope.builtin".lsp_document_symbols()<CR>', keymap_opts)
  buf_set_keymap('n', 'K', '<cmd>lua show_documentation()<CR>', keymap_opts)
  buf_set_keymap('n', '<C-Y>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', keymap_opts)
  buf_set_keymap('n', 'gr', '<cmd>lua require"telescope.builtin".lsp_references()<CR>', keymap_opts)
  buf_set_keymap('n', '<leader>gr', '<cmd>lua require"telescope.builtin".lsp_references()<CR>', keymap_opts)
  buf_set_keymap('n', '<leader>lci', '<cmd>lua vim.lsp.buf.incoming_calls()<CR>', keymap_opts)
  buf_set_keymap('n', '<leader>lco', '<cmd>lua vim.lsp.buf.outgoing_calls()<CR>', keymap_opts)

  buf_set_keymap('n', '<leader>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', keymap_opts)
  buf_set_keymap('n', '<leader>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', keymap_opts)
  buf_set_keymap('n', '<leader>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', keymap_opts)

  buf_set_keymap('n', '<leader>a', '<cmd>lua require("telescope.builtin").lsp_code_actions()<CR>', keymap_opts)

  buf_set_keymap('n', '<leader>de', '<cmd>lua require"telescope.builtin".lsp_document_diagnostics({severity = "ERROR"})<CR>', keymap_opts)
  buf_set_keymap('n', '<leader>dd', '<cmd>lua require"telescope.builtin".lsp_document_diagnostics()<CR>', keymap_opts)
  buf_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', keymap_opts)
  buf_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', keymap_opts)
  buf_set_keymap('n', '[e', '<cmd>lua vim.lsp.diagnostic.goto_prev({severity = "Error"})<CR>', keymap_opts)
  buf_set_keymap('n', ']e', '<cmd>lua vim.lsp.diagnostic.goto_next({severity = "Error"})<CR>', keymap_opts)

  buf_set_keymap('n', '<M-F>', '<cmd>lua vim.lsp.buf.formatting()<CR>', keymap_opts)
  buf_set_keymap('v', '<M-F>', '<cmd>lua vim.lsp.buf.range_formatting({})<CR>', keymap_opts)
  buf_set_keymap('x', '<M-F>', '<cmd>lua vim.lsp.buf.range_formatting({})<CR>', keymap_opts)

  local old_on_attach = lsp_opts.on_attach

  lsp_opts.on_attach = function(client, bufnr)
    lsp_status.on_attach(client)

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

run_checkstyle = function()
  -- checkstyle error format
  vim.api.nvim_command('set makeprg=brazil-build')
  vim.api.nvim_command('set errorformat=[ant:checkstyle]\\ [%.%#]\\ %f:%l:%c:\\ %m,[ant:checkstyle]\\ [%.%#]\\ %f:%l:\\ %m')
  vim.api.nvim_command('set shellpipe=2>&1\\ \\|\\ tee\\ /tmp/checkstyle-errors.txt\\ \\|\\ grep\\ ERROR\\ &>\\ %s')
  vim.api.nvim_command('make check --rerun-tasks')
end

--------------------------------------------------------------
-- > JAVA SPECIFIC LSP CONFIG
--------------------------------------------------------------
local on_java_attach = function(client, bufnr)
  require'jdtls.setup'.add_commands()


  -- Java specific mappings
  buf_set_keymap("n", "<leader>lc", "<Cmd>lua run_checkstyle()<CR>", keymap_opts)
  buf_set_keymap("n", "<leader>li", "<Cmd>lua require'jdtls'.organize_imports()<CR>", keymap_opts)
  buf_set_keymap("v", "<leader>le", "<Esc><Cmd>lua require('jdtls').extract_variable(true)<CR>", keymap_opts)
  buf_set_keymap("n", "<leader>le", "<Cmd>lua require('jdtls').extract_variable()<CR>", keymap_opts)
  buf_set_keymap("v", "<leader>lm", "<Esc><Cmd>lua require('jdtls').extract_method(true)<CR>", keymap_opts)
  buf_set_keymap("n", "<leader>a", "<Cmd>lua require('jdtls').code_action()<CR>", keymap_opts)
  buf_set_keymap("x", "<leader>a", "<Esc><Cmd>lua require('jdtls').code_action(true)<CR>", keymap_opts)
  -- overwrite default vimspector launch mapping
  buf_set_keymap("n", "<Bslash>l", "<Cmd>lua start_vimspector_java()<CR>", keymap_opts)
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

-- DEBUGGINS WITH VIMSPECTOR
start_vimspector_java = function()
  -- need to start java-debug adapter first and pass it's port to vimspector
  require'jdtls.util'.execute_command({command = 'vscode.java.startDebugSession'}, function(err0, port)
    assert(not err0, vim.inspect(err0))

    vim.cmd("call vimspector#LaunchWithSettings(#{ AdapterPort: " .. port .. ", configuration: 'Java Attach' })")
  end, 0)
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

  vim.api.nvim_command("command! CleanJavaWorkspace :!rm -rf '" .. eclipse_workspace .. "' <bar> :StopLsp <bar> :StartJavaLsp")
  buf_set_keymap("n", "<leader>lr", "<Cmd>CleanJavaWorkspace<CR>", keymap_opts)

end

EOF

command! StopLsp :lua vim.lsp.stop_client(vim.lsp.get_active_clients())
command! StartJavaLsp :lua setup_java_lsp()
nnoremap <silent> <leader>lj :StartJavaLsp<CR>

augroup jdtls_lsp
    autocmd!
    autocmd FileType java lua setup_java_lsp()
augroup end

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => replacer
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
nnoremap <silent> <leader>rq :lua require("replacer").run()<cr>

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => nvimtree.2
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
lua << EOF
require'nvim-tree'.setup {
  -- updates the root directory of the tree on `DirChanged` (when your run `:cd` usually)
  update_cwd = false,

  view = {
    width= 45
  },

  -- updates the root directory of the tree on `DirChanged` (when your run `:cd` usually)
  update_cwd = true,

  -- update the focused file on `BufEnter`, un-collapses the folders recursively until it finds the file
  update_focused_file = {
    enable = true,
  },

  filters = {
    custom = { '.git', '.cache' }
  }
}
EOF

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => syntastic config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 0
let g:syntastic_check_on_wq = 0

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Indentation highlighting with blankline
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
lua << EOF
require("indent_blankline").setup {
  space_char_blankline = " ",
  show_current_context = true,
  use_treesitter = true,
  buftype_exclude = {'help', 'nerdtree', 'startify', 'LuaTree', 'TelescopePrompt', 'terminal'},
  show_first_indent_level = false,
  context_patterns = { 'class', 'function', 'method', 'expression', 'statement' }
}
EOF

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => treesitter config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
lua << EOF
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
EOF

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Terminal toggle config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
lua require("toggleterm").setup{
  \ open_mapping = [[<c-\>]]
  \ }
" turn terminal to normal mode with escape
tnoremap <Esc> <C-\><C-n>
" start terminal in insert mode
" and do not show terminal buffers in buffer list
augroup terminal
au!
au TermOpen * setlocal nobuflisted
" au BufEnter * if &buftype == 'terminal' | :startinsert | endif
augroup END


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => vim-sneak
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" remap default keybindings to sneak
map f <Plug>Sneak_f
map F <Plug>Sneak_F
map t <Plug>Sneak_t
map T <Plug>Sneak_T

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => git signs and hunks
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
lua require('gitsigns').setup{}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => revision diff config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
lua require('diffview').setup{}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => telescope fuzzy finder
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Find files using Telescope command-line sugar.
lua << EOF
require'telescope'.setup {
  defaults = {
    prompt_prefix="🔍"
  },
  pickers = {
    find_files = {
      previewer = false,
      theme = "dropdown",
      path_display={"smart", "shorten"}
    },
    live_grep = {
      previewer = false,
      theme = "ivy",
      path_display={"smart", "shorten"},
      only_sort_text=true
    },
    buffers = {
      theme = "ivy",
      path_display={"smart", "shorten"}
    }
  }
}
EOF

" file navigation
nnoremap <leader>p :lua require("telescope.builtin").find_files()<cr>
nnoremap <leader>bb :lua require("telescope.builtin").buffers()<cr>

" global search, useful with qf + replacer
nnoremap <leader>fg :lua require("telescope.builtin").live_grep()<cr>

" git helpers
nnoremap <leader>vb :lua require("telescope.builtin").git_branches()<cr>
nnoremap <leader>vb :lua require("telescope.builtin").git_stash()<cr>

" general pickers
nnoremap <leader>gc :lua require("telescope.builtin").commands()<cr>
nnoremap <leader>gh :lua require("telescope.builtin").help_tags()<cr>
nnoremap <leader>gm :lua require("telescope.builtin").keymaps()<cr>

" resume prev picker with state
nnoremap <leader>rr :lua require("telescope.builtin").resume()<cr>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => bufferline
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" NOTE: If barbar's option dict isn't created yet, create it
let bufferline = get(g:, 'bufferline', {})

" Enable/disable animations
let bufferline.animation = v:true

" Enable/disable auto-hiding the tab bar when there is a single buffer
let bufferline.auto_hide = v:false

" Enable/disable current/total tabpages indicator (top right corner)
let bufferline.tabpages = v:true

" Enable/disable close button
let bufferline.closable = v:true

" Enables/disable clickable tabs
"  - left-click: go to buffer
"  - middle-click: delete buffer
let bufferline.clickable = v:true

" Enable/disable icons
" if set to 'numbers', will show buffer index in the tabline
" if set to 'both', will show buffer index and icons in the tabline
let bufferline.icons = v:true

" Sets the icon's highlight group.
" If false, will use nvim-web-devicons colors
let bufferline.icon_custom_colors = v:false

" Configure icons on the bufferline.
let bufferline.icon_separator_active = '▎'
let bufferline.icon_separator_inactive = '▎'
let bufferline.icon_close_tab = ''
let bufferline.icon_close_tab_modified = '●'

" Sets the maximum padding width with which to surround each tab
let bufferline.maximum_padding = 4

" If set, the letters for each buffer in buffer-pick mode will be
" assigned based on their name. Otherwise or in case all letters are
" already assigned, the behavior is to assign letters in order of
" usability (see order below)
let bufferline.semantic_letters = v:true

" New buffer letters are assigned in this order. This order is
" optimal for the qwerty keyboard layout but might need adjustement
" for other layouts.
let bufferline.letters =
  \ 'asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP'

nnoremap <silent> <leader>bp :BufferPick<cr>

" Close the current buffer
nnoremap <silent> <leader>bd :BufferClose<cr>
nnoremap <silent> <A-l> :BufferNext<cr>
nnoremap <silent> <A-h> :BufferPrevious<cr>
" Close all the buffers
nnoremap <silent> <leader>bda :bufdo bd<cr>

" Close all buffers but the current one
" command! BufOnly silent! execute "%bd|e#|db#"
nnoremap <silent> <leader>bdo :BufferCloseAllButCurrent<cr>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => vim-test framework for testing
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
nnoremap <silent> <leader>in :execute('TestNearest '.g:test_extra_flags)<cr>
nnoremap <silent> <leader>if :execute('TestFile '.g:test_extra_flags)<cr>
nnoremap <silent> <leader>is :execute('TestSuite '.g:test_extra_flags)<cr>
nnoremap <silent> <leader>il :execute('TestLast '.g:test_extra_flags)<cr>
nnoremap <silent> <leader>ig :execute('TestVisit '.g:test_extra_flags)<cr>
" for maven set to something like this:
"  -Dtests.additional.jvmargs="'-Xdebug -Xrunjdwp:transport=dt_socket,address=localhost:5005,server=y,suspend=y'"
" for gradle use:
"  --debug-jvm
let g:test_debug_flags = ''
let g:test_extra_flags = ''
nnoremap <leader>idf :let g:test_debug_flags=""
nnoremap <leader>ie :let g:test_debug_flags=""
nnoremap <leader>id :execute('TestNearest '.g:test_extra_flags.' '.g:test_debug_flags)<cr>
nnoremap <leader>ids :execute('TestSuite '.g:test_extra_flags.' '.g:test_debug_flags)<cr>

let test#strategy = 'neovim'

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => GoYo and Limeline configuration to define Zen mode
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:limelight_conceal_ctermfg = 240

let s:zen_mode=0
function ToggleZen()
  if s:zen_mode
    " Disable zen mode
    let s:zen_mode = 0
    call ToggleRelativeNumbers(1)
    :Goyo!
    :Limelight!
  else
    " Enable zen mode
    let s:zen_mode = 1
    call ToggleRelativeNumbers(0)
    :Goyo
    :Limelight
  endif
endfunction
command! -nargs=0 Zen :call ToggleZen()

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Startify configurations
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" save current layout into session
nmap <leader>ss :SSave!<cr>

let g:startify_session_before_save = [
    \ 'echo "Cleaning up before saving.."',
    \ 'silent! NvimTreeClose'
    \ ]

let g:startify_session_persistence = 1

" save coc's workspace folders between sessions
let g:startify_session_savevars = [
  \ 'g:startify_session_savevars',
  \ 'g:startify_session_savecmds',
  \ 'g:WorkspaceFolders'
  \ ]

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Rose-pint
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
lua vim.g.rose_pine_variant = 'moon'
lua vim.g.rose_pine_bold_vertical_split_line = true

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Tokyonight
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" NOTE: has to precede the color scheme settings
let g:tokyonight_style = 'storm'
let g:tokyonight_sidebars = [ 'nerdtree', 'terminal', "LuaTree", "sidebarnvim" ]
let g:tokyonight_hide_inactive_statusline = v:true
let g:tokyonight_italic_comments = v:true

" map json file type for jsonc to allow comments
autocmd! BufRead,BufNewFile *.json set filetype=jsonc

autocmd! BufRead,BufNewFile *sqc,*HPP,*CPP set filetype=cpp

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Colors and Fonts
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" THIS IS PURE FUCKING EVIL!!! DO NOT E-V-E-R SET THIS OPTION
" screws up all of the terminal colors, completely.
" going to leave it here is a reminder...
" OH HOW THINGS HAVE CHANGED)
set termguicolors

lua <<EOF
local color_scheme = require('solarized')
color_scheme.load{
    theme = 'dark',  -- or 'light'
    italic_comments = true,
    italic_strings = true
}
EOF

" colorscheme rose-pine
autocmd ColorScheme tokyonight highlight! link LineNr Question
autocmd ColorScheme tokyonight highlight! link CursorLineNr Question
" Update bracket matching highlight group to something sane that can be read
" Apparently, there is such a thing as dynamic color scheme, so
" register an autocomand to make sure that we update the highlight
" group when color scheme changes
autocmd ColorScheme shades_of_purple highlight! link MatchParen Search


" Enable syntax highlighting
syntax enable
set background=dark

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Helper functions
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Returns true if paste mode is enabled
function! HasPaste()
    if &paste
        return 'PASTE MODE  '
    endif
    return ''
endfunction

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


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Git-gutter configuration
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
command! Gqf GitGutterQuickFix | copen
nmap <silent> <leader>hqf :Gqf<cr>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Git fugivite split diff
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
command! DiffHistory call s:view_git_history()

function! s:view_git_history() abort
  Git difftool --name-only ! !^@
  call s:diff_current_quickfix_entry()
  " Bind <CR> for current quickfix window to properly set up diff split layout after selecting an item
  " There's probably a better way to map this without changing the window
  copen
  nnoremap <buffer> <CR> <CR><BAR>:call <sid>diff_current_quickfix_entry()<CR>
  wincmd p
endfunction

function s:diff_current_quickfix_entry() abort
  " Cleanup windows
  for window in getwininfo()
    if window.winnr !=? winnr() && bufname(window.bufnr) =~? '^fugitive:'
      exe 'bdelete' window.bufnr
    endif
  endfor
  cc
  call s:add_mappings()
  let qf = getqflist({'context': 0, 'idx': 0})
  if get(qf, 'idx') && type(get(qf, 'context')) == type({}) && type(get(qf.context, 'items')) == type([])
    let diff = get(qf.context.items[qf.idx - 1], 'diff', [])
    echom string(reverse(range(len(diff))))
    for i in reverse(range(len(diff)))
      exe (i ? 'leftabove' : 'rightbelow') 'vert diffsplit' fnameescape(diff[i].filename)
      call s:add_mappings()
    endfor
  endif
endfunction

function! s:add_mappings() abort
  nnoremap <buffer>]q :cnext <BAR> :call <sid>diff_current_quickfix_entry()<CR>
  nnoremap <buffer>[q :cprevious <BAR> :call <sid>diff_current_quickfix_entry()<CR>
  " Reset quickfix height. Sometimes it messes up after selecting another item
  11copen
  wincmd p
endfunction

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

" ----------------------------------------------------------------------------
" Evil line configuration for galaxyline
" ----------------------------------------------------------------------------

lua << EOF
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
  file = '',
  dotdotdot = '…',
  information = '',
  symlink = '',
  line_number = '',
  debug = '',
  trace = '✎',
  git = {
    unstaged = '✗',
    staged = '✓',
    unmerged = '',
    renamed = '➜',
    untracked = '★',
    deleted = '',
    ignored = '◌',
  },
  folder = {
    arrow_open = '',
    arrow_closed = '',
    default = '',
    open = '',
    empty = '',
    empty_open = '',
    symlink = '',
    symlink_open = '',
  },
}

local colors = {
    bg = '#282c34',
    line_bg = '#353644',
    fg = '#8FBCBB',
    fg_green = '#65a380',

    yellow = '#fabd2f',
    cyan = '#008080',
    darkblue = '#081633',
    green = '#afd700',
    orange = '#FF8800',
    purple = '#5d4d7a',
    magenta = '#c678dd',
    blue = '#51afef',
    red = '#ec5f67',
    white = '#FFFFFF'
}

local get_mode = function()
  local mode_colors = {
    [110] = { 'NORMAL', colors.blue, colors.bg },
    [105] = { 'INSERT', colors.cyan, colors.bg },
    [99] = { 'COMMAND', colors.orange, colors.bg },
    [116] = { 'TERMINAL', colors.blue, colors.bg },
    [118] = { 'VISUAL', colors.purple, colors.bg },
    [22] = { 'V-BLOCK', colors.purple, colors.bg },
    [86] = { 'V-LINE', colors.purple, colors.bg },
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

local function lsp_status(status)
    shorter_stat = ''
    for match in string.gmatch(status, "[^%s]+")  do
        err_warn = string.find(match, "^[WE]%d+", 0)
        if not err_warn then
            shorter_stat = shorter_stat .. ' ' .. match
        end
    end
    return shorter_stat
end


local function get_coc_lsp()
  local status = require'lsp-status'.status()
  if not status or status == '' then
      return ''
  end
  return status
end

function get_diagnostic_info()
  if #vim.lsp.buf_get_clients() > 0 then
    return get_coc_lsp()
    end
  return ''
end

local function get_current_func()
  local has_func, func_name = pcall(vim.fn.nvim_buf_get_var,0,'coc_current_function')
  if not has_func then return end
      return func_name
  end

function get_function_info()
  if vim.fn.exists('*coc#rpc#start_server') == 1 then
    return get_current_func()
    end
  return ''
end

local function trailing_whitespace()
    local trail = vim.fn.search("\\s$", "nw")
    if trail ~= 0 then
        return ' '
    else
        return nil
    end
end

CocStatus = get_diagnostic_info
CocFunc = get_current_func
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
    CocStatus = {
      provider = {
        BracketProvider(icons.arrow_right, true),
        CocStatus
      },
      highlight = 'GalaxyViModeInv',
    }
  },
}

highlight('GalaxyDiagnosticError', colors.red, colors.bg)
highlight('GalaxyDiagnosticErrorInv', colors.bg, colors.red)

highlight('GalaxyDiagnosticWarn', colors.yellow, colors.bg)
highlight('GalaxyDiagnosticWarnInv', colors.bg, colors.yellow)

highlight('GalaxyDiagnosticInfo', colors.purple, colors.bg)
highlight('GalaxyDiagnosticInfoInv', colors.bg, colors.purple)

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
      highlight = { colors.white, colors.bg },
    },
  },
  {
    GhostShort = {
      provider = BracketProvider(icons.ghost, true),
      highlight = { colors.bg, colors.white },
    },
  },
  {
    GhostRightBracketShort = {
      provider = BracketProvider(icons.rounded_right_filled, true),
      highlight = { colors.white, colors.bg },
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
      highlight = { colors.white, colors.bg },
    },
  },
  {
    FileNameShort = {
      provider = 'FileName',
      condition = condition.buffer_not_empty,
      highlight = { colors.white, colors.bg },
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
      highlight = { colors.white, colors.bg },
    },
  },
  {
    ShortPerCent = {
      provider = {
        PercentProvider,
      },
      separator = icons.arrow_left .. ' ',
      highlight = { colors.white, colors.bg },
    },
  },
}
EOF

" ------------------------------------------------------
"  Additional runtime path and script locations
" ------------------------------------------------------

" source any additional configuration files that i don't want to check in git
call s:source_all_additional_files(stdpath('config').'/additional')
set runtimepath^=$HOME/.config/nvim/additional

