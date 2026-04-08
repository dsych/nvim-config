return {
    "OXY2DEV/markview.nvim",
    lazy = false, -- Recommended
    dependencies = {
        "nvim-tree/nvim-web-devicons"
    },
    name = "markview",
    config = function()
        local ag = vim.api.nvim_create_augroup("markdown_preview", {
            clear = true
        })

        vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
            pattern = { "*.md" },
            callback = function(args)
                vim.print(args)
                vim.print(args.file.gmatch(args.file, "(design)")())
                if not args.file.gmatch(args.file, "(design)")() then
                    vim.cmd('Markview Enable')
                else
                    vim.cmd('Markview Disable')
                end
            end,
            group = ag,
        })

        vim.api.nvim_create_autocmd({ "WinNew" }, {
            callback = function(args)
                if vim.bo[args.buf].buftype == "nofile" and vim.bo[args.buf].filetype == "markdown" then
                    vim.api.nvim_buf_call(args.buf, function()
                        vim.cmd('Markview Enable')
                    end)
                else
                    vim.cmd('Markview Disable')
                end
            end,
            group = ag,
        })

        require("markview").setup({
            preview = {
                filetypes = {
                    'md',
                    'markdown',
                    'norg',
                    'rmd',
                    'org',
                    'vimwiki',
                    'typst',
                    'latex',
                    'quarto',
                    -- 'Avante',
                    'codecompanion',
                },
                ignore_buftypes = {},
                enable_hybrid_mode = false
            }
        })
    end
}
