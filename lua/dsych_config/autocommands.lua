
-- Return to last edit position when opening files
vim.cmd([[
    augroup last_cursor_position
        autocmd!
        autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
    augroup END
]])


vim.cmd([[
    augroup remove_whitespace
        autocmd!
        autocmd BufWritePre * :lua CleanExtraSpaces()
    augroup END
]])

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

