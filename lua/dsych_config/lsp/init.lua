local utils = require"dsych_config.utils"
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
	["ts_ls"] = function ()
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
	end,
}

M.setup = function()
	local server_configs = require("dsych_config.lsp").language_server_configs

	-- automatically install these language servers
	local servers_to_install = {
		"clangd",
		"cssls",
		"html",
		"jsonls",
		"lemminx",
		"basedpyright",
		"lua_ls",
		"ts_ls",
		"vimls",
		"bashls",
		"yamlls",
		"cucumber_language_server",
		"ruff"
	}

    require("mason").setup()
    require("mason-lspconfig").setup{
        ensure_installed = servers_to_install,
        automatic_installation = false -- { exclude = { "rust_analyzer" } }
    }

	-- install java decompiler manually
	require"mason-registry".get_package("vscode-java-decompiler"):install()

	-- rely on a manual rust installation
	local servers = vim.fn.deepcopy(servers_to_install)
	table.insert(servers, "rust_analyzer")

	local lsp_utils = require("dsych_config.lsp.utils")
    local lsp_config = require"lspconfig"

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
		if server_name == "ts_ls" then
			require"dsych_config.lsp.tsserver".config(config)
		elseif server_name == "cucumber_language_server" then
			lsp_config[server_name].setup(require"dsych_config.lsp.cucumber"(config))
		elseif server_name == "ruff" then
			lsp_config[server_name].setup(require"dsych_config.lsp.ruff"(config))
		else
			lsp_config[server_name].setup(config)
		end
    end
end

return M
