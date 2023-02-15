local M = {}

-- DEBUGGINS WITH VIMSPECTOR
M.start_vimspector_java = function()
	-- need to start java-debug adapter first and pass it's port to vimspector
	require("jdtls.util").execute_command({ command = "vscode.java.startDebugSession" }, function(err0, port)
		assert(not err0, vim.inspect(err0))

		vim.fn["vimspector#LaunchWithSettings"]({ AdapterPort = port, configuration = "Java Attach" })
	end, 0)
end

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
		-- overwrite default vimspector launch mapping
		map_key("n", "<Bslash>l", require("dsych_config.lsp.jdtls").start_vimspector_java)
        map_key("n", "<M-F>", function() vim.lsp.buf.format({ filter = function(cl) return cl.name == "jdtls" end }) end)
        map_key({ "v", "x" }, "<M-F>", function() vim.lsp.buf.format({ filter = function(cl) return cl.name == "jdtls" end }) end)
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
			},
		}
		config.cmd = { "jdtls" , "--run", "--workspace", eclipse_workspace }
		config.on_attach = on_java_attach
		-- SUPER IMPORTANT, this will prevent lsp from launching in
		-- every workspaces
		config.root_dir = root_dir

        local bundles = {
          vim.fn.glob(home .. "/.local/source/jdtls-launcher/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-*.jar"),
        }
        vim.list_extend(bundles, vim.split(vim.fn.glob(home .. "/.local/source/jdtls-launcher/vscode-java-decompiler/server/*.jar"), "\n"))

		local extendedClientCapabilities = require("jdtls").extendedClientCapabilities
		extendedClientCapabilities.resolveAdditionalTextEditsSupport = true
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
			":!rm -rf '" .. eclipse_workspace .. "' <bar> :StopLsp <bar> :StartJavaLsp",
			{}
		)
		map_key("n", "<leader>lr", "<Cmd>CleanJavaWorkspace<CR>")
	end

	vim.api.nvim_create_user_command("StopLsp", function()
		vim.lsp.stop_client(vim.lsp.get_active_clients())
	end, {})
	vim.api.nvim_create_user_command("StartJavaLsp", setup_java_lsp, {})
	map_key("n", "<leader>lj", "<cmd>StartJavaLsp<cr>")

	vim.cmd([[
        autocmd FileType java :lua setup_java_lsp()
    ]])
end

return M
