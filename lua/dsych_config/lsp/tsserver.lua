local M = {}

local on_ts_attach = function(old_on_attach)
    return function(client, bufnr)
        if old_on_attach then
            old_on_attach(client, bufnr)
        end

        local map_key = require("dsych_config.utils").map_key
        local opts = { buffer = bufnr }

        map_key("n", "<leader>li", "<cmd>TSToolsOrganizeImports<cr>", opts)
        map_key("n", "<leader>lu", "<cmd>TSToolsRemoveUnused<cr>", opts)
        map_key("n", "gd", "<cmd>TSToolsGoToSourceDefinition<cr>", opts)
    end
end

M.config = function(config)
    -- wrap the on_attach from the previous config with on_attach specific to ts_ls
    config.on_attach = on_ts_attach(config.on_attach)

    require("typescript-tools").setup {
        server = config
    }
end

return M
