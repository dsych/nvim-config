local M = {}

M.language_server_configs = {
  ["sumneko_lua"] = function()
    local runtime_path = vim.split(package.path, ';')
    table.insert(runtime_path, "lua/?.lua")
    table.insert(runtime_path, "lua/?/init.lua")

    return {
        settings = {
            Lua = {
              runtime = {
                version = "LuaJIT"
              },
              diagnostics = {
                -- Get the language server to recognize the 'vim', 'use' global
                globals = {'vim', 'use'},
              },
              workspace = {
                -- Make the server aware of Neovim runtime files
                library = vim.api.nvim_get_runtime_file("", true)
              },
              -- Do not send telemetry data containing a randomized but unique identifier
              telemetry = {
                enable = false,
              },
            },
        }
    }
  end
}

M.enable_lsp_status = function()
    local lsp_status = require'lsp-status'

    lsp_status.config{
      diagnostics = false,
      show_filename = false
    }
end

M.setup = function ()
    local server_configs = require'dsych_config.lsp'.language_server_configs

    require'dsych_config.lsp'.enable_lsp_status()

    local lsp_utils = require'dsych_config.lsp.utils'
    local lsp_installer = require("nvim-lsp-installer")
    -- actually start the language server
    lsp_installer.on_server_ready(function(server)
      local config = vim.tbl_deep_extend("force", lsp_utils.mk_config(), server_configs[server.name] and server_configs[server.name]() or {})
      server:setup(lsp_utils.configure_lsp(config))
    end)
end

return M
