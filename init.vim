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

" remap leader to space
nnoremap <space> <Nop>
let mapleader=" "

" Sets how many lines of history VIM has to remember
set history=500

nnoremap <silent> <leader>z  :stop<cr>

" escape insert mode with jk
imap <silent> jk <esc>

" copy and paste from/to the system clipboard
map <silent> <leader><c-p> "+p<cr>
map <silent> <leader><c-y> "+y<cr>

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
" display tabs as vertical bars
" :set list
" :set lcs=tab:\|\  " the last character is space!

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

" Format the status line
" set statusline=\ %{HasPaste()}%F%m%r%h\ %w\ \ CWD:\ %r%{getcwd()}%h\ \ \ Line:\ %l\ \ Column:\ %c

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

if has("autocmd")
    autocmd BufWritePre * :call CleanExtraSpaces()
endif

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
" => Nerd commenter config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
map <silent> <leader>c <plug>NERDCommenterToggle
" Add spaces after comment delimiters by default
let g:NERDSpaceDelims = 1
" Allow commenting and inverting empty lines (useful when commenting a region)
let g:NERDCommentEmptyLines = 1
" Enable trimming of trailing whitespace when uncommenting
let g:NERDTrimTrailingWhitespace = 1

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => nvimtree.1, see after pluging
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
map <silent> <leader>e :NvimTreeToggle<cr>
map <silent> <leader>ef :NvimTreeFindFile<cr>
let g:nvim_tree_auto_ignore_ft = [ 'startify', 'dashboard' ] "empty by default, don't auto open tree on specific filetypes.
let g:nvim_tree_quit_on_open = 1 "0 by default, closes the tree when you open a file
let g:nvim_tree_indent_markers = 1 "0 by default, this option shows indent markers when folders are open
let g:nvim_tree_add_trailing = 1 "0 by default, append a trailing slash to folder names
let g:nvim_tree_group_empty = 1 " 0 by default, compact folders that only contain a single folder into one node in the file tree
let g:nvim_tree_ignore = [ '.git', '.cache' ]
let g:nvim_tree_special_files = { 'README.md': 1, 'Makefile': 1, 'MAKEFILE': 1 } " List of filenames that gets highlighted with NvimTreeSpecialFile

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Vimspector
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:vimspector_enable_mappings = 'VISUAL_STUDIO'

" for normal mode - the word under the cursor
nmap <Leader>di <Plug>VimspectorBalloonEval
" for visual mode, the visually selected text
xmap <Leader>di <Plug>VimspectorBalloonEval

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
Plug 'neoclide/coc.nvim', {'branch': 'release'}
" all the extensions for coc-nvim
let g:coc_global_extensions=[ 'coc-actions', 'coc-java', 'coc-java-debug', 'coc-json', 'coc-marketplace', 'coc-pairs', 'coc-prettier', 'coc-spell-checker', 'coc-terminal', 'coc-tsserver', "coc-html", "coc-css", "coc-vimlsp", "coc-pyright", "coc-cmake", "coc-emmet", "coc-clangd", "coc-angular"]

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
Plug 'preservim/nerdcommenter'

" file explorer
Plug 'kyazdani42/nvim-tree.lua'

" file indentation detection
Plug 'tpope/vim-sleuth'

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

" style checker
" Plug 'vim-syntastic/syntastic'

Plug 'satabin/hocon-vim'

" markdown preview
" depends on https://github.com/charmbracelet/glow
Plug 'ellisonleao/glow.nvim'

" search and replace inside quickfix window
Plug 'gabrielpoca/replacer.nvim'

call plug#end()

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
  buftype_exclude = {'help', 'nerdtree', 'startify', 'LuaTree', 'TelescopePrompt'},
  show_first_indent_level = false
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
    enable = true
  }
}
EOF

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Terminal toggle config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" map <leader>j <Plug>(coc-terminal-toggle)
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

nnoremap <leader>p :lua require("telescope.builtin").find_files()<cr>
nnoremap <leader>fg :lua require("telescope.builtin").live_grep()<cr>
nnoremap <leader>bb :lua require("telescope.builtin").buffers()<cr>
nnoremap <leader>rr :lua require("telescope.builtin").resume()<cr>
nnoremap <leader>gh :Telescope help_tags<cr>
nnoremap <leader>gm :Telescope keymaps<cr>

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
nnoremap <silent> <leader>in :TestNearest<cr>
nnoremap <silent> <leader>if :TestFile<cr>
nnoremap <silent> <leader>is :TestSuite<cr>
nnoremap <silent> <leader>il :TestLast<cr>
nnoremap <silent> <leader>ig :TestVisit<cr>
" for maven set to something like this:
"  -Dtests.additional.jvmargs="'-Xdebug -Xrunjdwp:transport=dt_socket,address=localhost:5005,server=y,suspend=y'"
" for gradle use:
"  --debug-jvm
let g:test_debug_flags = ''
nnoremap <leader>ids :let g:test_debug_flags=""
nnoremap <leader>id :execute('TestNearest'.g:test_debug_flags)<cr>

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

colorscheme rose-pine
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

" Enable 256 colors palette in Gnome Terminal
" if $COLORTERM == 'gnome-terminal'
" set t_Co=256
" endif


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>  Sessions
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
" delays and poor user experience.
set updatetime=300

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>  COC.NVIM config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" TextEdit might fail if hidden is not set.
set hidden

" Some servers have issues with backup files, see #649.
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
if has("patch-8.1.1564")
  " Recently vim can merge signcolumn and number column into one
  set signcolumn=number
else
  set signcolumn=yes
endif

" Use tab for trigger completion with characters ahead and navigate.
" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
" other plugin before putting this into your config.
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion.
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

" Make <CR> auto-select the first completion item and notify coc.nvim to
" format on enter, <cr> could be remapped by other vim plugin
inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

" view previous diagnostic
nmap <silent> <leader>dp <Plug>(coc-diagnostic-prev-error)
" view next diagnostic
nmap <silent> <leader>dn <Plug>(coc-diagnostic-next-error)
" Show all diagnostics.
nnoremap <silent> <leader>da  :<C-u>CocList diagnostics<cr>

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window.
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  elseif (coc#rpc#ready())
    call CocActionAsync('doHover')
  else
    execute '!' . &keywordprg . " " . expand('<cword>')
  endif
endfunction

" Highlight the symbol and its references when holding the cursor.
autocmd CursorHold * silent call CocActionAsync('highlight')

" Symbol renaming.
nmap <leader>grn <Plug>(coc-rename)

" Formatting selected code.
xmap <leader>gf  <Plug>(coc-format-selected)
nmap <leader>gf  <Plug>(coc-format-selected)

augroup mygroup
  autocmd!
  " Setup formatexpr specified filetype(s).
  autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
  " Update signature help on jump placeholder.
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

" Applying codeAction to the selected region.
" Example: `<leader>aap` for current paragraph
xmap <leader>a  <Plug>(coc-codeaction-cursor)
nmap <leader>a  <Plug>(coc-codeaction-cursor)

" Apply AutoFix to problem on the current line.
nmap <leader>qf  <Plug>(coc-fix-current)

" Map function and class text objects
" NOTE: Requires 'textDocument.documentSymbol' support from the language server.
xmap if <Plug>(coc-funcobj-i)
omap if <Plug>(coc-funcobj-i)
xmap af <Plug>(coc-funcobj-a)
omap af <Plug>(coc-funcobj-a)
xmap ic <Plug>(coc-classobj-i)
omap ic <Plug>(coc-classobj-i)
xmap ac <Plug>(coc-classobj-a)
omap ac <Plug>(coc-classobj-a)

" Remap <C-f> and <C-b> for scroll float windows/popups.
nnoremap <expr><C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
nnoremap <expr><C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
inoremap <expr><C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<Right>"
inoremap <expr><C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<Left>"

" Use CTRL-S for selections ranges.
" Requires 'textDocument/selectionRange' support of language server.
nmap <silent> <C-s> <Plug>(coc-range-select)
xmap <silent> <C-s> <Plug>(coc-range-select)

" Add `:Format` command to format current buffer.
command! -nargs=0 -range Format :call CocAction('format')
map <A-F> :Format<cr>

" Add `:Fold` command to fold current buffer.
command! -nargs=? Fold :call     CocAction('fold', <f-args>)

" Add `:OR` command for organize imports of the current buffer.
command! -nargs=0 OR   :call     CocAction('runCommand', 'editor.action.organizeImport')

" Mappings for CoCList
" Manage extensions.
nnoremap <silent> <leader>le  :<C-u>CocList extensions<cr>
" Open the marketplace
nnoremap <silent> <leader>lm  :<C-u>CocList marketplace<cr>
" Show commands.
nnoremap <silent> <f1>  :<C-u>CocList commands<cr>
" Find symbol of current document.
nnoremap <silent> <leader>lo  :<C-u>CocList outline<cr>
" Search workspace symbols.
nnoremap <silent> <leader>ls  :<C-u>CocList -I symbols<cr>
" Do default action for next item.
nnoremap <silent> <leader>lj  :<C-u>CocNext<CR>
" Do default action for previous item.
nnoremap <silent> <leader>lk  :<C-u>CocPrev<CR>
" Resume latest coc list.
nnoremap <silent> <leader>lp  :<C-u>CocListResume<CR>

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

-- VistaPlugin = extension.vista_nearest

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
    blue = '#51afef';
    red = '#ec5f67'
}

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
  local status = vim.fn['coc#status']()
  if not status or status == '' then
      return ''
  end
  return lsp_status(status)
end

function get_diagnostic_info()
  if vim.fn.exists('*coc#rpc#start_server') == 1 then
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

gls.left[1] = {
  FirstElement = {
    provider = function() return ' ' end,
    highlight = {colors.blue,colors.line_bg}
  },
}
gls.left[2] = {
  ViMode = {
    provider = function()
      -- auto change color according the vim mode
      local alias = {
          n = 'NORMAL',
          i = 'INSERT',
          c= 'COMMAND',
          V= 'VISUAL',
          [''] = 'VISUAL',
          v ='VISUAL',
          c  = 'COMMAND-LINE',
          ['r?'] = ':CONFIRM',
          rm = '--MORE',
          R  = 'REPLACE',
          Rv = 'VIRTUAL',
          s  = 'SELECT',
          S  = 'SELECT',
          ['r']  = 'HIT-ENTER',
          [''] = 'SELECT',
          t  = 'TERMINAL',
          ['!']  = 'SHELL',
      }
      local mode_color = {
          n = colors.green,
          i = colors.blue,v=colors.magenta,[''] = colors.blue,V=colors.blue,
          c = colors.red,no = colors.magenta,s = colors.orange,S=colors.orange,
          [''] = colors.orange,ic = colors.yellow,R = colors.purple,Rv = colors.purple,
          cv = colors.red,ce=colors.red, r = colors.cyan,rm = colors.cyan, ['r?'] = colors.cyan,
          ['!']  = colors.green,t = colors.green,
          c  = colors.purple,
          ['r?'] = colors.red,
          ['r']  = colors.red,
          rm = colors.red,
          R  = colors.yellow,
          Rv = colors.magenta,
      }
      local vim_mode = vim.fn.mode()
      vim.api.nvim_command('hi GalaxyViMode guifg='..mode_color[vim_mode])
      return alias[vim_mode] .. ' '
    end,
    highlight = {colors.red,colors.line_bg,'bold'},
  },
}
gls.left[3] ={
  FileIcon = {
    provider = 'FileIcon',
    condition = buffer_not_empty,
    highlight = {require('galaxyline.provider_fileinfo').get_file_icon_color,colors.line_bg},
  },
}
gls.left[4] = {
  FileName = {
    provider = {'FileName'},
    condition = buffer_not_empty,
    highlight = {colors.fg,colors.line_bg,'bold'}
  }
}

gls.left[6] = {
  GitBranch = {
    provider = 'GitBranch',
    condition = require('galaxyline.provider_vcs').check_git_workspace,
    highlight = {colors.orange,colors.line_bg,'bold'},
  }
}

local checkwidth = function()
  local squeeze_width  = vim.fn.winwidth(0) / 2
  if squeeze_width > 40 then
    return true
  end
  return false
end

gls.left[7] = {
  DiffAdd = {
    provider = 'DiffAdd',
    condition = checkwidth,
    icon = ' ',
    highlight = {colors.green,colors.line_bg},
  }
}
gls.left[8] = {
  DiffModified = {
    provider = 'DiffModified',
    condition = checkwidth,
    icon = ' ',
    highlight = {colors.orange,colors.line_bg},
  }
}
gls.left[9] = {
  DiffRemove = {
    provider = 'DiffRemove',
    condition = checkwidth,
    icon = ' ',
    highlight = {colors.red,colors.line_bg},
  }
}
gls.left[10] = {
  LeftEnd = {
    provider = function() return '' end,
    separator = '',
    separator_highlight = {colors.bg,colors.line_bg},
    highlight = {colors.line_bg,colors.line_bg}
  }
}

gls.left[11] = {
    TrailingWhiteSpace = {
     provider = TrailingWhiteSpace,
     icon = '  ',
     highlight = {colors.yellow,colors.bg},
    }
}

gls.left[12] = {
  DiagnosticError = {
    provider = 'DiagnosticError',
    icon = '  ',
    highlight = {colors.red,colors.bg}
  }
}
gls.left[13] = {
  Space = {
    provider = function () return ' ' end
  }
}
gls.left[14] = {
  DiagnosticWarn = {
    provider = 'DiagnosticWarn',
    icon = '  ',
    highlight = {colors.yellow,colors.bg},
  }
}


gls.left[15] = {
    CocStatus = {
     provider = CocStatus,
     highlight = {colors.green,colors.bg},
     icon = '  '
    }
}

gls.left[16] = {
  CocFunc = {
    provider = CocFunc,
    icon = '  λ ',
    highlight = {colors.yellow,colors.bg},
  }
}

gls.right[1]= {
  FileFormat = {
    provider = 'FileFormat',
    separator = ' ',
    separator_highlight = {colors.bg,colors.line_bg},
    highlight = {colors.fg,colors.line_bg,'bold'},
  }
}
gls.right[4] = {
  LineInfo = {
    provider = 'LineColumn',
    separator = ' | ',
    separator_highlight = {colors.blue,colors.line_bg},
    highlight = {colors.fg,colors.line_bg},
  },
}
gls.right[5] = {
  PerCent = {
    provider = 'LinePercent',
    separator = ' ',
    separator_highlight = {colors.line_bg,colors.line_bg},
    highlight = {colors.cyan,colors.darkblue,'bold'},
  }
}

-- gls.right[4] = {
--   ScrollBar = {
--     provider = 'ScrollBar',
--     highlight = {colors.blue,colors.purple},
--   }
-- }
--
-- gls.right[3] = {
--   Vista = {
--     provider = VistaPlugin,
--     separator = ' ',
--     separator_highlight = {colors.bg,colors.line_bg},
--     highlight = {colors.fg,colors.line_bg,'bold'},
--   }
-- }

gls.short_line_left[1] = {
  BufferType = {
    provider = 'FileTypeName',
    separator = '',
    condition = has_file_type,
    separator_highlight = {colors.purple,colors.bg},
    highlight = {colors.fg,colors.purple}
  }
}


gls.short_line_right[1] = {
  BufferIcon = {
    provider= 'BufferIcon',
    separator = '',
    condition = has_file_type,
    separator_highlight = {colors.purple,colors.bg},
    highlight = {colors.fg,colors.purple}
  }
}
EOF

" ------------------------------------------------------
"  Additional runtime path and script locations
" ------------------------------------------------------
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

" source any additional configuration files that i don't want to check in git
call s:source_all_additional_files($HOME.'/.config/nvim/additional')
set runtimepath^=$HOME/.config/nvim/additional

