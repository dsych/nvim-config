local mason = require "dsych_config.utils.mason"

local M = {}

M.setup = function()
	local map_key = require("dsych_config.utils").map_key
	local lsp_utils = require("dsych_config.lsp.utils")

	local on_java_attach = function(client, bufnr)
		require("jdtls.setup").add_commands()

		-- Java specific mappings
		map_key("n", "<leader>li", require("jdtls").organize_imports)
		map_key("v", "<leader>le", "<Esc><Cmd>lua require('jdtls').extract_variable(true)<CR>")
		map_key("n", "<leader>le", "<Cmd>lua require('jdtls').extract_variable()<CR>")
		map_key("v", "<leader>lm", "<Esc><Cmd>lua require('jdtls').extract_method(true)<CR>")
        -- require'formatter'.setup{
        --     filetype = {
        --         java = {
        --             function()
        --                 return {
        --                     exe = 'java',
        --                     args = { '-jar', os.getenv('HOME') .. '/.local/jars/google-java-format.jar', vim.api.nvim_buf_get_name(0) },
        --                     stdin = true
        --                 }
        --             end
        --         }
        --     }
        -- }

		-- vim.api.nvim_exec([[
		--   augroup FormatAutogroup
		--     autocmd!
		--     autocmd BufWritePost *.java FormatWrite
		--   augroup end
		-- ]], true)
		-- buf_set_keymap('n', '<leader>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
	end

	function setup_java_lsp()
		local root_dir = get_java_root and get_java_root() or require("jdtls.setup").find_root({ "gradlew", ".git" })

		local home = os.getenv("HOME")
		-- where eclipse stores runtime files about current project
		local eclipse_workspace = home .. "/.local/share/eclipse/" .. vim.fn.fnamemodify(root_dir, ":p:h:t")

		local ws_folders_lsp = get_java_workspaces and get_java_workspaces(root_dir) or {}
		local ws_folders_jdtls = {}
		for _, ws in ipairs(ws_folders_lsp) do
			table.insert(ws_folders_jdtls, string.format("file://%s", ws))
		end

		local capabilities = vim.lsp.protocol.make_client_capabilities()

		capabilities.workspace.configuration = true
		capabilities.textDocument.completion.completionItem.snippetSupport = true

		local config = lsp_utils.mk_config()
		config.settings = {
			-- ['java.format.settings.url'] = home .. "/.config/nvim/language-servers/java-google-formatter.xml",
			-- ['java.format.settings.profile'] = "GoogleStyle",
			java = {
				signatureHelp = { enabled = true },
				contentProvider = { preferred = "fernflower" },
				completion = {
					favoriteStaticMembers = {
						"org.hamcrest.MatcherAssert.assertThat",
						"org.hamcrest.Matchers.*",
						"org.hamcrest.CoreMatchers.*",
						"org.junit.jupiter.api.Assertions.*",
						"java.util.Objects.requireNonNull",
						"java.util.Objects.requireNonNullElse",
						"org.mockito.Mockito.*",
					},
				},
				inlayHints = { parameterNames = { enabled = "all" } };
				sources = {
					organizeImports = {
						starThreshold = 9999,
						staticStarThreshold = 9999,
					},
				},
				codeGeneration = {
					toString = {
						template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
					},
				},
                configuration = {
                    runtimes = {
                        {
                            name = 'JavaSE-17',
                            path = vim.fn.expandcmd"$JAVA_HOME_17"
                        },
                        {
                            name = 'JavaSE-11',
                            path = vim.fn.expandcmd"$JAVA_HOME_11",
                        },
						{
                            name = 'JavaSE-1.8',
                            path = vim.fn.expandcmd"$JAVA_HOME_8",
                            default = true
						}
                    }
                },
			},
		}
		config.cmd = { "jdtls" , "--run", "--workspace", eclipse_workspace }
		config.on_attach = on_java_attach
		-- SUPER IMPORTANT, this will prevent lsp from launching in
		-- every workspaces
		config.root_dir = root_dir

		local bundles = {}

		table.insert(bundles, mason.get_package_path_with_fallback(
            "java-debug-adapter",
            "/extension/server/com.microsoft.java.debug.plugin-*.jar",
            home .. "/.local/source/jdtls-launcher/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-*.jar"
        ))
		vim.list_extend(bundles, vim.split(mason.get_package_path_with_fallback(
            "vscode-java-decompiler",
            "/server/*.jar",
			home .. "/.local/source/jdtls-launcher/vscode-java-decompiler/server/*.jar"
        ), "\n"))
		vim.list_extend(bundles, vim.split(mason.get_package_path_with_fallback(
            "java-test",
            "/extension/server/*.jar"
        ), "\n"))

		local extendedClientCapabilities = require("jdtls").extendedClientCapabilities
		extendedClientCapabilities.resolveAdditionalTextEditsSupport = true
		extendedClientCapabilities.onCompletionItemSelectedCommand = "editor.action.triggerParameterHints"
		config.init_options = {
			-- jdtls extensions e.g. debugging
			bundles = bundles,
			extendedClientCapabilities = extendedClientCapabilities,
			workspaceFolders = ws_folders_jdtls,
		}

		-- start the server
		require("jdtls").start_or_attach(lsp_utils.configure_lsp(config))

		vim.api.nvim_create_user_command(
			"CleanJavaWorkspace",
            function ()
                vim.cmd("!rm -rf '" .. eclipse_workspace .. "'")
                vim.cmd("StopLsp")
                vim.cmd("StartJavaLsp")
            end,
			{}
		)
		map_key("n", "<leader>lr", "<Cmd>CleanJavaWorkspace<CR>")
	end

	vim.api.nvim_create_user_command("StopLsp", function()
		vim.lsp.stop_client(vim.lsp.get_clients())
	end, {})
	vim.api.nvim_create_user_command("StartJavaLsp", setup_java_lsp, {})
	map_key("n", "<leader>lj", "<cmd>StartJavaLsp<cr>")

	vim.cmd([[
        autocmd FileType java :lua setup_java_lsp()
    ]])
end

return M
