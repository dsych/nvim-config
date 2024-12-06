return {
    "OXY2DEV/markview.nvim",
    lazy = false,      -- Recommended
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
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
    end
}
