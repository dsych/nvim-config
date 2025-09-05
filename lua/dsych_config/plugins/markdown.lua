return {
    "OXY2DEV/markview.nvim",
    lazy = false,      -- Recommended
    dependencies = {
        "nvim-tree/nvim-web-devicons"
    },
    config = function ()
        local ag = vim.api.nvim_create_augroup("markdown_preview", {
            clear = true
        })

        vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
            pattern = {"*.md"},
            command = "Markview",
            group = ag,
        })

        vim.api.nvim_create_autocmd({"WinNew"}, {
            callback = function (args)
                if vim.bo[args.buf].buftype == "nofile" and vim.bo[args.buf].filetype == "markdown" then
                    vim.api.nvim_buf_call(args.buf, function ()
                        vim.cmd('Markview')
                    end)
                end
            end,
            group = ag,
        })

        require("markview").setup({
            preview = {
                ignore_buftypes = {}
            }
        })
    end
}
