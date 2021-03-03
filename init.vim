"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => General
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if has('win32') || has('win64')
  let &shell='cmd.exe'
endif
" increase timeout between keys
set timeoutlen=1500

" remap leader to space
nnoremap <space> <Nop>
let mapleader=" "

" Sets how many lines of history VIM has to remember
set history=500

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
:set list
:set lcs=tab:\|\  " the last character is space!

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

" Enable mouse for all modes
set mouse=a

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

" Find in the current buffer
map <silent> <leader>bf :BLines<cr>

" Global searches
map <leader>fg :Ag

" Display all buffers
map <silent> <leader>bb :Buffers<cr>

" Close the current buffer
map <silent> <leader>bd :bp\|bd #<cr>

" Close all the buffers
map <silent> <leader>bda :bufdo bd<cr>
" Close all buffers but the current one
command! BufOnly silent! execute "%bd|e#|db#"
map <silent> <leader>bdo :BufOnly<cr>

map <silent> <leader>l :bnext<cr>
map <silent> <leader>h :bprevious<cr>

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
" => NERD git plugin
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:NERDTreeGitStatusUseNerdFonts = 1

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Terminal toggle config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
map <leader>j <Plug>(coc-terminal-toggle)

" turn terminal to normal mode with escape
tnoremap <Esc> <C-\><C-n>
" close terminal right away. useful for fzf commands
tnoremap <C-c> <C-q>
" start terminal in insert mode
au BufEnter * if &buftype == 'terminal' | :startinsert | endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Explorer config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
map <silent> <leader>e :NERDTreeToggle<cr>
map <silent> <leader>ef :NERDTreeFind<cr>
autocmd StdinReadPre * let s:std_in=1
" Automatically close nvim if NERDTree is only thing left open
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
" show nerd tree automatically, if no file buffer is open on startup
" autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif

" open nerd tree automatically, if nvim is opened against a directory
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists("s:std_in") | exe 'NERDTree' argv()[0] | wincmd p | ene | exe 'cd '.argv()[0] | endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => FZF search config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" map  <leader>p :call fzf#run(fzf#wrap({'sink': 'e'}))<cr>
" let g:fzf_layout = { 'down': '20%' }
let g:fzf_layout = { 'window': '10new' }
nmap <leader>p :Files<cr>

if executable("ag")
  " requires silversearcher-ag
  " used to ignore gitignore files
  let $FZF_DEFAULT_COMMAND = 'ag -g ""'
endif

let g:fzf_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-s': 'split',
  \ 'ctrl-v': 'vsplit'
  \}

" only search for file content rather than filename for Ag command
command! -bang -nargs=* Ag call fzf#vim#ag(<q-args>, {'options': '--delimiter : --nth 4..'}, <bang>0)

" Fuzzy find help for plugin
map <silent> <leader>gh :Helptags!<cr>

" Fuzzy find mappings for the normal mode
map <silent> <leader>gm :Maps<cr>

" function! RipgrepFzf(query, fullscreen)
" let command_fmt = rg --column --line-number --no-heading --color=always --smart-case -- %s || true''
" let initial_command = printfcommand_fmt, shellescape(a:query())
" let reload_command = printfcommand_fmt, '(q}{')
" let spec = '{options': [--phony'', '--query', a:query, --bind'', 'change:reload:'.reload_command]}
  " call fzf#vim#grep(initial_command, 1, fzf#vim#with_preview(spec), a:fullscreen)
" endfunction
"
" command! -nargs=* -bang Rg call RipgrepFzf(<q-args, <>bang>0)]}})
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Action menu config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Remap for do codeAction of selected region
function! s:cocActionsOpenFromSelected(type) abort
  execute 'CocCommand actions.open ' . a:type
endfunction
xmap <silent> <leader>a :<C-u>execute 'CocCommand actions.open ' . visualmode()<CR>
nmap <silent> <leader>a :<C-u>set operatorfunc=<SID>cocActionsOpenFromSelected<CR>g@

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Plugins
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
call plug#begin('~/.vim/plugged')

" language server
Plug 'neoclide/coc.nvim', {'branch': 'release'}
" all the extensions for coc-nvim
let g:coc_global_extensions=[ 'coc-actions', 'coc-explorer', 'coc-java', 'coc-java-debug', 'coc-json', 'coc-marketplace', 'coc-pairs', 'coc-prettier', 'coc-spell-checker', 'coc-terminal', 'coc-tsserver', "coc-html", "coc-css", "coc-vimlsp", "coc-pyright"]

" status line
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" debugging
Plug 'puremourning/vimspector'

" theme
Plug 'morhetz/gruvbox'

" files search
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

Plug 'tpope/vim-fugitive'

" start screen
Plug 'mhinz/vim-startify'

" commenting
Plug 'preservim/nerdcommenter'

" begin order matters here
" file explorer
Plug 'preservim/nerdtree'

Plug 'Xuyuanp/nerdtree-git-plugin'

" file explorer icons
Plug 'ryanoasis/vim-devicons'
" end order matters here

" file indentation detection
Plug 'tpope/vim-sleuth'

Plug 'neoclide/jsonc.vim'

Plug 'jackguo380/vim-lsp-cxx-highlight'

Plug 'Rigellute/shades-of-purple.vim'

Plug 'airblade/vim-gitgutter'

" Focused writting
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'

call plug#end()

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
let g:startify_session_before_save = [
    \ 'echo "Cleaning up before saving.."',
    \ 'silent! NERDTreeTabsClose'
    \ ]

let g:startify_session_persistence = 1

" save coc's workspace folders between sessions
let g:startify_session_savevars = [
  \ 'g:startify_session_savevars',
  \ 'g:startify_session_savecmds',
  \ 'g:WorkspaceFolders'
  \ ]


" save current layout into session
nmap <leader>ss :SSave!<cr>

" map json file type for jsonc to allow comments
autocmd! BufRead,BufNewFile *.json set filetype=jsonc

autocmd! BufRead,BufNewFile *sqc,*HPP,*CPP set filetype=cpp
let g:airline_powerline_fonts = 1
" let g:airline_section_b = '%{getcwd()}' " in section B of the status line display the CWD

" do not show file encoding if it matches this sting
let g:airline#parts#ffenc#skip_expected_string='utf-8[unix]'

let g:airline_stl_path_style = 'short'
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Tabline
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:airline#extensions#tabline#enabled = 1           " enable airline tabline
let g:airline#extensions#tabline#show_close_button = 0 " remove 'X' at the end of the tabline
let g:airline#extensions#tabline#tabs_label = ''       " can put text here like BUFFERS to denote buffers (I clear it so nothing is shown)
let g:airline#extensions#tabline#buffers_label = ''    " can put text here like TABS to denote tabs (I clear it so nothing is shown)
let g:airline#extensions#tabline#fnamemod = ':t'       " disable file paths in the tab
let g:airline#extensions#tabline#show_tab_count = 1    " dont show tab numbers on the right
let g:airline#extensions#tabline#show_buffers = 0      " dont show buffers in the tabline
let g:airline#extensions#tabline#show_splits = 1       " enable the buffer name that displays on the right of the tabline
let g:airline#extensions#tabline#show_tab_nr = 1       " disables tab numbers
let g:airline#extensions#tabline#show_tab_type = 0     " disables the weird ornage arrow on the tabline
let g:airline#extensions#tabline#buffer_idx_mode = 1
let g:airline#extensions#tabline#tab_min_count = 0
let g:airline#extensions#tabline#buffer_nr_show = 1

let g:airline#extensions#tabline#alt_sep = 1

" do not show warnings
let g:airline_section_warning = ''
let g:airline_skip_empty_sections = 1

let g:airline#extensions#tabline#exclude_preview = 0
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Colors and Fonts
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" THIS IS PURE FUCKING EVIL!!! DO NOT E-V-E-R SET THIS OPTION
" screws up all of the terminal colors, completely.
" going to leave it here is a reminder...
" set termguicolors

colorscheme shades_of_purple
" Update bracket matching highlight group to something sane that can be read
" Apparently, there is such a thing as dynamic color scheme, so
" register an autocomand to make sure that we update the highlight
" group when color scheme changes
autocmd ColorScheme shades_of_purple highlight! link MatchParen Search


" Enable syntax highlighting
syntax enable
set background=dark

" let g:airline_theme='gruvbox'
let g:shades_of_purple_airline = 1
let g:airline_theme='shades_of_purple'

" Enable 256 colors palette in Gnome Terminal
" if $COLORTERM == 'gnome-terminal'
    set t_Co=256
" endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>  Sessions
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
" delays and poor user experience.
set updatetime=300

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" =>  Vimspector
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:vimspector_enable_mappings = 'VISUAL_STUDIO'

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
nmap <silent> <leader>dp <Plug>(coc-diagnostic-prev)
" view next diagnostic
nmap <silent> <leader>dn <Plug>(coc-diagnostic-next)
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
xmap <leader>a  <Plug>(coc-codeaction-selected)
nmap <leader>a  <Plug>(coc-codeaction-selected)

" Remap keys for applying codeAction to the current buffer.
nmap <leader>ac  <Plug>(coc-codeaction)
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
command! -nargs=0 Format :call CocAction('format')
map <A-F> :Format<cr>

" Add `:Fold` command to fold current buffer.
command! -nargs=? Fold :call     CocAction('fold', <f-args>)

" Add `:OR` command for organize imports of the current buffer.
command! -nargs=0 OR   :call     CocAction('runCommand', 'editor.action.organizeImport')

" Add (Neo)Vim's native statusline support.
" NOTE: Please see `:h coc-status` for integrations with external plugins that
" provide custom statusline: lightline.vim, vim-airline.
" set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}

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

" my coc extensions
" set runtimepath^=/home/dmytro/workspace/coc-cmake-tools
