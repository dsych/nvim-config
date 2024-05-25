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
	["tsserver"] = function ()
		return {
			settings = {
				typescript = {
				  inlayHints = {
					includeInlayParameterNameHints = 'all',
					includeInlayParameterNameHintsWhenArgumentMatchesName = false,
					includeInlayFunctionParameterTypeHints = true,
					includeInlayVariableTypeHints = false,
					includeInlayVariableTypeHintsWhenTypeMatchesName = false,
					includeInlayPropertyDeclarationTypeHints = true,
					includeInlayFunctionLikeReturnTypeHints = true,
					includeInlayEnumMemberValueHints = true,
				  }
				},
				javascript = {
				  inlayHints = {
					includeInlayParameterNameHints = 'all',
					includeInlayParameterNameHintsWhenArgumentMatchesName = false,
					includeInlayFunctionParameterTypeHints = true,
					includeInlayVariableTypeHints = true,
					includeInlayVariableTypeHintsWhenTypeMatchesName = false,
					includeInlayPropertyDeclarationTypeHints = true,
					includeInlayFunctionLikeReturnTypeHints = true,
					includeInlayEnumMemberValueHints = true,
				  }
				}
			}
		}
	end,
	["bashls"] = function ()
		return {
			filetypes = { "sh", "zsh" }
		}
	end,
	['rust_analyzer'] = function ()
		return {
			check = {
				command = "clippy";
			},
			diagnostics = {
				enable = true;
			}
		}
	end
}

M.setup = function()
	local server_configs = require("dsych_config.lsp").language_server_configs

	require("lsp-inlayhints").setup()

	-- automatically install these language servers
	local servers_to_install = {
		-- "clangd",
		"cssls",
		"html",
		"jsonls",
		"lemminx",
		"pyright",
		"lua_ls",
		"tsserver",
		"vimls",
		"bashls",
		"yamlls",
		"cucumber_language_server",
		"solargraph"
	}

    require("mason").setup()
    require("mason-lspconfig").setup{
        ensure_installed = servers_to_install,
        automatic_installation = false -- { exclude = { "rust_analyzer" } }
    }

	-- rely on a manual rust installation
	local servers = vim.tbl_deep_extend("force", servers_to_install, { "rust_analyzer" })

	local lsp_utils = require("dsych_config.lsp.utils")
    local lsp_config = require"lspconfig"

	-- configure lua_ls for neovim plugin development
	require"neodev".setup()

    -- -- FIXME: workaround for high cpu usage in the recent nighty release because of the new file watcher
    -- local ok, wf = pcall(require, "vim.lsp._watchfiles")
    -- if ok then
    --     -- disable lsp watcher. Too slow on linux
    --     wf._watchfunc = function()
    --         return function() end
    --     end
    -- end

	-- actually start the language server
    for _, server_name in ipairs(servers) do
		local config = vim.tbl_deep_extend(
			"force",
			lsp_utils.mk_config(),
			server_configs[server_name] and server_configs[server_name]() or {}
		)
		config = lsp_utils.configure_lsp(config)
		if server_name == "tsserver" then
			require"dsych_config.lsp.tsserver".config(config)
		else
			lsp_config[server_name].setup(config)
		end
    end
end

return M
