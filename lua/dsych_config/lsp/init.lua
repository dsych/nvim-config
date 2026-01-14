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
	['basedpyright'] = function ()
		return {
			settings = {
				pyright = {
					-- Using Ruff's import organizer
					disableOrganizeImports = true,
				},
				python = {
					analysis = {
						-- Ignore all files for analysis to exclusively use Ruff for linting
						ignore = { '*' },
					},
				},
			},
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
	['clangd'] = function ()
		local compile_command_option = ""

		if derive_additional_clangd_cmd_flags then
			compile_command_option = derive_additional_clangd_cmd_flags()
		end

		local settings = {
			cmd = {
				"clangd",
				"-j",
				tostring(math.floor(#vim.loop.cpu_info() * 0.66)),
				"--background-index",
				"--malloc-trim",
				"--pch-storage=memory",
				"--background-index"
			}

		}
		if compile_command_option ~= "" then
			table.insert(settings.cmd, compile_command_option)
		end

		return settings
	end,
	["gopls"] = function ()
		return {
			settings = {
				gopls = {
					completeUnimported = true,
					usePlaceholders = true,
					analyses = {
						unusedparams = true,
					},
				},
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
		"vimls",
		"bashls",
		"yamlls",
		"cucumber_language_server",
		"ruff",
		-- "gopls",
		"neocmake"
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
	table.insert(servers, "ts_ls")

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
		else
			if server_name == "cucumber_language_server" then
				vim.lsp.config(server_name, require"dsych_config.lsp.cucumber"(config))
			elseif server_name == "ruff" then
				vim.lsp.config(server_name, require"dsych_config.lsp.ruff"(config))
			elseif server_name == "gopls" then
				vim.lsp.config(server_name, require"dsych_config.lsp.gopls"(config))
			else
				vim.lsp.config(server_name, config)
			end

			vim.lsp.enable(server_name)
		end
    end
end

return M
