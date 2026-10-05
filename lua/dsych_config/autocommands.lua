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

vim.cmd([[
    augroup markdown
      autocmd!
      autocmd FileType markdown :set textwidth=120
    augroup END
]])

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("python_config", {clear = true}),
    pattern = "python",
    command = "set textwidth=0"
})

-- Focus flash: when nvim gains focus (tmux pane/window switch, terminal
-- refocus) briefly highlight the cursor line so the eye lands on the cursor.
-- Pairs with the tmux pane-focus-in flash, which can't show over nvim: nvim
-- paints its own background and zoomed panes have no border. tmux forwards
-- focus changes because tmux.conf sets focus-events on.
-- Disable with vim.g.focus_flash = false; restyle with the FocusFlash group.
vim.api.nvim_set_hl(0, "FocusFlash", { link = "Visual", default = true })
local focus_flash_ns = vim.api.nvim_create_namespace("focus_flash")
local focus_flash = { timer = nil, buf = nil }
local function focus_flash_clear()
    if focus_flash.timer and not focus_flash.timer:is_closing() then
        focus_flash.timer:stop()
        focus_flash.timer:close()
    end
    focus_flash.timer = nil
    if focus_flash.buf and vim.api.nvim_buf_is_valid(focus_flash.buf) then
        vim.api.nvim_buf_clear_namespace(focus_flash.buf, focus_flash_ns, 0, -1)
    end
    focus_flash.buf = nil
end
vim.api.nvim_create_autocmd("FocusGained", {
    group = my_auto_group,
    callback = function()
        if vim.g.focus_flash == false then return end
        focus_flash_clear()
        local buf = vim.api.nvim_get_current_buf()
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        -- A ranged highlight to end of line, not line_hl_group: CursorLine
        -- wins over line_hl_group, and this is always the cursor's line.
        vim.api.nvim_buf_set_extmark(buf, focus_flash_ns, row, 0, {
            end_row = row + 1, end_col = 0, hl_group = "FocusFlash",
            hl_eol = true, priority = 10000, strict = false,
        })
        focus_flash.buf = buf
        focus_flash.timer = vim.uv.new_timer()
        focus_flash.timer:start(vim.g.focus_flash_ms or 250, 0, vim.schedule_wrap(focus_flash_clear))
    end,
})
