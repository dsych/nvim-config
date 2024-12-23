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

vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    group = my_auto_group,
    callback = function (event)
        local file_path = vim.api.nvim_buf_get_name(event.buf)
        local textwidth = 120
        if file_path:gmatch(".*/designs?/.*")() then
            -- disable hard line wrapping as it's harder to import markdown due to line breaks
            textwidth = 0
            -- because hard breaks are disabled, enable virtual wrapping instead
            vim.wo[vim.api.nvim_get_current_win()].wrap = true
        end
        vim.bo[event.buf].textwidth = textwidth
    end
})
