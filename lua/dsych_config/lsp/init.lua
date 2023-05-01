local M = {}

M.language_server_configs = {
	["lua_ls"] = function()
		return {
			settings = {
				Lua = {
	 				-- Do not send telemetry data containing a randomized but unique identifier
					telemetry = {
						enable = false,
					},
				},
			},
		}
	end,
	["jsonls"] = function()
		return {
			settings = {
				json = {
					schemas = require("schemastore").json.schemas(),
				},
			},
		}
	end,
}

M.enable_lsp_status = function()
	local lsp_status = require("lsp-status")

	lsp_status.config({
		diagnostics = false,
		show_filename = false,
        status_symbol = ""
	})

	lsp_status.register_progress()
end

M.setup = function()
	local server_configs = require("dsych_config.lsp").language_server_configs

	require("dsych_config.lsp").enable_lsp_status()

	-- automatically install these language servers
	local servers = {
		"clangd",
		"cssls",
		"html",
		"jsonls",
		"lemminx",
		"pyright",
		"lua_ls",
		"tsserver",
		"vimls",
		"bashls",
		"yamlls"
	}

    require("mason").setup()
    require("mason-lspconfig").setup{
        ensure_installed = servers,
        automatic_installation = true
    }

	local lsp_utils = require("dsych_config.lsp.utils")
    local lsp_config = require"lspconfig"

	-- configure lua_ls for neovim plugin development
	require"neodev".setup()

	-- actually start the language server
    for _, server_name in ipairs(servers) do
		local config = vim.tbl_deep_extend(
			"force",
			lsp_utils.mk_config(),
			server_configs[server_name] and server_configs[server_name]() or {}
		)
        lsp_config[server_name].setup(lsp_utils.configure_lsp(config))
    end
end

return M
