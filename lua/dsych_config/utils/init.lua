local M = {}

M.source_all_additional_files = function (dir_path)
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

M.map_key = function(mode, lhs, rhs, opts)
    opts = opts or {}
    vim.keymap.set(mode, lhs, rhs, vim.tbl_deep_extend("force", { noremap = true, silent = false }, opts))
end

-- toggle to absolute line numbers in insert mode and when buffer loses focus
M.toggle_relative_numbers = function(mode)
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
]])


-- Delete trailing white space on save, useful for some filetypes ;)
function CleanExtraSpaces()
    local save_cursor = vim.fn.getpos(".")
    local old_query = vim.fn.getreg('/')
    vim.api.nvim_command("silent! %s/\\s\\+$//e")
    vim.fn.setpos('.', save_cursor)
    vim.fn.setreg('/', old_query)
end

M.load_spell_file = function()
    local syntax_spell_file = vim.fn["spell#GetSyntaxFile"](vim.opt.filetype:get())

    if vim.opt.spell:get() and vim.fn.filereadable(syntax_spell_file) then
        vim.fn["spell#LoadSyntaxFile"]()
    end
end


M.show_documentation = function()
  if vim.tbl_contains({ 'vim', 'help' }, vim.opt.filetype:get()) then
    vim.api.nvim_command('h '..vim.api.nvim_eval('expand("<cword>")'))
  elseif not vim.tbl_isempty(vim.lsp.buf_get_clients()) then
    vim.lsp.buf.hover()
  else
    vim.api.nvim_command('!'..vim.opt.keywordprg..' '..vim.fn.expand("<cword>"))
  end
end

return M
