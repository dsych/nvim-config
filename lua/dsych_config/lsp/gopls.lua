local map_key = require("dsych_config.utils").map_key
local lsp_utils = require("dsych_config.lsp.utils")

local M = {}

return function (config)
    local old_on_attach = config.on_attah


    config.on_attach = function (client, bufnr)
		map_key("n", "<leader>li", require("go.format").goimports)

        if old_on_attach then
            old_on_attach(client, buffer)
        end
    end

    return config
end
