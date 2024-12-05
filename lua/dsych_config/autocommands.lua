-- Return to last edit position when opening files
vim.cmd([[
    augroup last_cursor_position
        autocmd!
        autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
    augroup END
]])

local my_auto_group = vim.api.nvim_create_augroup("MyAutoCommands", {clear = true})

vim.api.nvim_create_autocmd({"BufWritePre"}, {
    pattern = "*",
    callback = function (event)
        -- exclude python files from automatic formatting
        if string.match(event.file, "%.py$") == nil then
            CleanExtraSpaces()
        end
    end,
    group = my_auto_group
})

-- vim.cmd([[
--     augroup remove_whitespace
--         autocmd!
--         autocmd BufWritePre * :lua CleanExtraSpaces()
--     augroup END
-- ]])

vim.cmd([[
    augroup markdown
      autocmd!
      autocmd FileType markdown :set textwidth=120
    augroup END
]])
