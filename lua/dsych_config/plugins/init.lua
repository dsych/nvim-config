local fn = vim.fn
local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
	packer_bootstrap = fn.system({
		"git",
		"clone",
		"--depth",
		"1",
		"https://github.com/wbthomason/packer.nvim",
		install_path,
	})
end

return require("packer").startup(function(use)
	-- Packer can manage itself
	use("wbthomason/packer.nvim")

	-- Recommended (for coloured icons)
	use({
		"kyazdani42/nvim-web-devicons",
	})

	-- autocompleteion {{{
	use({ "ms-jpq/coq.artifacts", branch = "artifacts" })
	use({ "ms-jpq/coq.thirdparty", branch = "3p" })
	use({
		"ms-jpq/coq_nvim",
		branch = "coq",
		requires = { "ms-jpq/coq.artifacts", "ms-jpq/coq.thirdparty" },
		run = ":COQdeps",
		config = function()
			vim.g.coq_settings = {
				auto_start = "shut-up",
				["display.icons.mode"] = "short",
				["display.icons.mappings"] = require("lspkind").presets.default,
				["keymap.jump_to_mark"] = "<C-S>",
			}
		end,
	})
	-- }}}

	-- language server {{{
	use({
		-- current function/lsp status
		"nvim-lua/lsp-status.nvim",
		-- icons
		"onsails/lspkind-nvim",
		-- signature help for functions lsp
		"ray-x/lsp_signature.nvim",
		"neovim/nvim-lspconfig",
	})

	use({
		"williamboman/nvim-lsp-installer",
		requires = {
			-- current function/lsp status
			"nvim-lua/lsp-status.nvim",
			-- icons
			"onsails/lspkind-nvim",
			-- signature help for functions lsp
			"ray-x/lsp_signature.nvim",
			"neovim/nvim-lspconfig",
			"ms-jpq/coq_nvim",
		},
		config = require("dsych_config.lsp").setup,
	})

	use({
		"b0o/schemastore.nvim",
		requires = {
			"williamboman/nvim-lsp-installer",
		},
	})

	use({
		-- java lsp client
		"mfussenegger/nvim-jdtls",
		requires = { "williamboman/nvim-lsp-installer" },
		config = require("dsych_config.lsp.jdtls").setup,
	})

	use({
		"jose-elias-alvarez/null-ls.nvim",
		requires = { "nvim-lua/plenary.nvim" },
		config = function()
			local null_ls = require("null-ls")
			null_ls.setup({
				sources = {
					null_ls.builtins.formatting.stylua,
					null_ls.builtins.formatting.clang_format,
					null_ls.builtins.formatting.prettier,

					null_ls.builtins.diagnostics.write_good,
					null_ls.builtins.diagnostics.cppcheck,
				},
			})
		end,
	})
	-- }}}

	-- bufferline {{{
	use({
		"romgrk/barbar.nvim",
		requires = { "kyazdani42/nvim-web-devicons" },
		config = function()
			local map_key = require("dsych_config.utils").map_key
			map_key("n", "<leader>bp", "<cmd>BufferPick<cr>")

			-- Close the current buffer
			map_key("n", "<leader>bd", "<cmd>BufferClose<cr>")
			map_key("n", "<A-l>", "<cmd>BufferNext<cr>")
			map_key("n", "<A-h>", "<cmd>BufferPrevious<cr>")
			-- Close all the buffers
			map_key("n", "<leader>bda", "<cmd>bufdo bd<cr>")

			-- Close all buffers but the current one
			-- command! BufOnly silent! execute --%bd|e#|db#--
			map_key("n", "<leader>bdo", "<cmd>BufferCloseAllButCurrent<cr>")
			vim.g.bufferline = {
				-- Enable/disable animations
				animation = true,

				-- Enable/disable auto-hiding the tab bar when there is a single buffer
				auto_hide = false,

				-- Enable/disable current/total tabpages indicator (top right corner)
				tabpages = true,

				-- Enable/disable close button
				closable = true,

				-- Enables/disable clickable tabs
				--  - left-click: go to buffer
				--  - middle-click: delete buffer
				clickable = true,

				-- Enable/disable icons
				-- if set to 'numbers', will show buffer index in the tabline
				-- if set to 'both', will show buffer index and icons in the tabline
				icons = true,

				-- Sets the icon's highlight group.
				-- If false, will use nvim-web-devicons colors
				icon_custom_colors = false,

				-- Configure icons on the bufferline.
				icon_separator_active = "▎",
				icon_separator_inactive = "▎",
				icon_close_tab = "",
				icon_close_tab_modified = "●",

				-- Sets the maximum padding width with which to surround each tab
				maximum_padding = 4,

				-- If set, the letters for each buffer in buffer-pick mode will be
				-- assigned based on their name. Otherwise or in case all letters are
				-- already assigned, the behavior is to assign letters in order of
				-- usability (see order below)
				semantic_letters = true,

				-- New buffer letters are assigned in this order. This order is
				-- optimal for the qwerty keyboard layout but might need adjustement
				-- for other layouts.
				letters = "asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP",
			}
		end,
	})
	-- }}}

	-- file explorer {{{
	use({
		"kyazdani42/nvim-tree.lua",
		config = function()
			local map_key = require("dsych_config.utils").map_key
			map_key("n", "<leader>e", "<cmd>NvimTreeToggle<cr>")
			map_key("n", "<leader>ef", "<cmd>NvimTreeFindFile<cr>")

			vim.g.nvim_tree_auto_ignore_ft = { "startify", "dashboard" } --empty by default, don't auto open tree on specific filetypes.
			vim.g.nvim_tree_quit_on_open = 1 --0 by default, closes the tree when you open a file
			vim.g.nvim_tree_indent_markers = 1 --0 by default, this option shows indent markers when folders are open=true
			vim.g.nvim_tree_add_trailing = 1 --0 by default, append a trailing slash to folder names
			vim.g.nvim_tree_group_empty = 1 -- 0 by default, compact folders that only contain a single folder into one node in the file tree
			vim.g.nvim_tree_special_files = {
				["README.md"] = true,
				Makefile = true,
				MAKEFILE = true,
				Config = true,
				["build.gradle"] = true,
				[".vimspector.json"] = true,
			} -- List of filenames that gets highlighted with NvimTreeSpecialFile

			require("nvim-tree").setup({
				view = {
					width = 50,
					number = true,
					relativenumber = true,
				},

				-- updates the root directory of the tree on `DirChanged` (when your run `:cd` usually)
				update_cwd = true,

				-- update the focused file on `BufEnter`, un-collapses the folders recursively until it finds the file
				update_focused_file = {
					enable = true,
				},

				filters = {
					custom = { ".git", ".cache" },
				},

				diagnostics = {
					enable = true,
					show_on_dirs = true,
					icons = {
						hint = "",
						info = "",
						warning = "",
						error = "",
					},
				},
			})
		end,
	})
	-- }}}

	-- debugging {{{
	use({
		"puremourning/vimspector",
		config = function()
			local map_key = require("dsych_config.utils").map_key

			-- for normal mode - the word under the cursor
			map_key("n", "<Bslash>e", "<Plug>VimspectorBalloonEval")
			-- for visual mode, the visually selected text
			map_key("x", "<Bslash>e", "<Plug>VimspectorBalloonEval")

			map_key("n", "<Bslash>c", "<Plug>VimspectorContinue")
			map_key("n", "<Bslash>l", "<Plug>VimspectorLaunch")
			map_key("n", "<Bslash>t", "<Plug>VimspectorStop")
			map_key("n", "<Bslash>r", "<Plug>VimspectorRestart")
			map_key("n", "<Bslash>p", "<Plug>VimspectorPause")
			map_key("n", "<Bslash>b", "<Plug>VimspectorToggleBreakpoint")
			map_key("n", "<Bslash>bc", "<Plug>VimspectorToggleConditionalBreakpoint")
			map_key("n", "<Bslash>bf", "<Plug>VimspectorAddFunctionBreakpoint")
			map_key("n", "<Bslash>br", "<Plug>VimspectorRunToCursor")
			map_key("n", "<Bslash>bda", "<cmd>call vimspector#ClearBreakpoints()<cr>")
			map_key("n", "<Bslash>s", "<Plug>VimspectorStepOver")
			map_key("n", "<Bslash>i", "<Plug>VimspectorStepInto")
			map_key("n", "<Bslash>o", "<Plug>VimspectorStepOut")
			map_key("n", "<Bslash>d", "<cmd>VimspectorReset<cr>")

			function save_vimspector_session()
				if vim.fn.filereadable("./.vimspector.json") then
					vim.api.nvim_command("silent! VimspectorMkSession")
				end
			end

			function load_vimspector_session()
				if vim.fn.filereadable("./.vimspector.session") then
					vim.api.nvim_command("silent! VimspectorLoadSession")
				end
			end

			vim.cmd([[
            augroup vimspector_session
              autocmd!
              autocmd VimLeave * :lua save_vimspector_session()
              autocmd VimEnter * :lua load_vimspector_session()
            augroup END
            ]])
		end,
	})
	-- }}}

	-- files search {{{
	use({
		"nvim-telescope/telescope.nvim",
		requires = {
			"nvim-lua/popup.nvim",
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope-ui-select.nvim",
		},
		config = function()
			local map_key = require("dsych_config.utils").map_key
			-- file navigation
			map_key("n", "<leader>p", require("telescope.builtin").find_files)
			map_key("n", "<leader>bb", require("telescope.builtin").buffers)

			-- global search, useful with qf + replacer
			map_key("n", "<leader>fg", require("telescope.builtin").live_grep)

			-- git helpers
			map_key("n", "<leader>vb", function()
				require("telescope.builtin").git_branches({
					cwd = vim.fn.fnamemodify(vim.fn.finddir(".git", "./;~"), ":p:h:h"),
				})
			end)
			map_key("n", "<leader>vs", function()
				require("telescope.builtin").git_stash({
					cwd = vim.fn.fnamemodify(vim.fn.finddir(".git", "./;~"), ":p:h:h"),
				})
			end)

			-- general pickers
			map_key("n", "<leader>gc", require("telescope.builtin").commands)
			map_key("n", "<leader>gh", require("telescope.builtin").help_tags)
			map_key("n", "<leader>gm", require("telescope.builtin").keymaps)

			-- resume prev picker with state
			map_key("n", "<leader>rr", require("telescope.builtin").resume)

			require("telescope").setup({
				defaults = {
					prompt_prefix = "🔍",
				},
				pickers = {
					find_files = {
						previewer = false,
						theme = "dropdown",
						path_display = { "smart", "shorten" },
						hidden = true,
					},
					live_grep = {
						theme = "ivy",
						path_display = {
							shorten = { len = 1, exclude = { 1, -1 } },
						},
						only_sort_text = true,
					},
					buffers = {
						previewer = false,
						theme = "ivy",
						path_display = {
							shorten = { len = 1, exclude = { 1, -1 } },
						},
					},
				},
				extensions = {
					["ui-select"] = {
						require("telescope.themes").get_dropdown(),
					},
				},
			})

			-- telescope extensions
			require("telescope").load_extension("ui-select")
		end,
	})
	-- }}}

	-- git helper {{{
	use({
		"tpope/vim-fugitive",
	})
	-- }}}

	-- start screen {{{
	use({
		"mhinz/vim-startify",
		config = function()
			local map_key = require("dsych_config.utils").map_key
			-- save current layout into session
			map_key("n", "<leader>ss", function()
				vim.cmd("SSave!")
			end)

			vim.g.startify_session_before_save = { 'echo "Cleaning up before saving.."', "silent! NvimTreeClose" }

			vim.g.startify_session_persistence = true

			-- save coc's workspace folders between sessions
			vim.g.startify_session_savevars = {
				"g:startify_session_savevars",
				"g:startify_session_savecmds",
				"g:WorkspaceFolders",
			}
		end,
	})
	-- }}}

	-- commenting {{{
	use({
		"b3nj5m1n/kommentary",
		config = function()
			require("kommentary.config").configure_language("default", {
				prefer_single_line_comments = true,
			})
			require("kommentary.config").configure_language(
				{ "typescriptreact", "html", "typescript", "javascript", "lua" },
				{
					single_line_comment_string = "auto",
					multi_line_comment_strings = "auto",
					hook_function = function()
						require("ts_context_commentstring.internal").update_commentstring()
					end,
				}
			)
		end,
	})
	-- }}}

	-- themes {{{
	use({
		"morhetz/gruvbox",
		"Rigellute/shades-of-purple.vim",
		"folke/tokyonight.nvim",
		"rose-pine/neovim",
	})
	use({
		"ishan9299/nvim-solarized-lua",
		setup = function()
			vim.cmd("autocmd ColorScheme tokyonight highlight! link LineNr Question")
			vim.cmd("autocmd ColorScheme tokyonight highlight! link CursorLineNr Question")
			-- Update bracket matching highlight group to something sane that can be read
			-- Apparently, there is such a thing as dynamic color scheme, so
			-- register an autocomand to make sure that we update the highlight
			-- group when color scheme changes
			vim.cmd("autocmd ColorScheme shades_of_purple highlight! link MatchParen Search")

			------------------------------------------------------------------------------------------------------------------------------
			-- => Rose-pint
			------------------------------------------------------------------------------------------------------------------------------
			vim.g.rose_pine_variant = "moon"
			vim.g.rose_pine_bold_vertical_split_line = true

			------------------------------------------------------------------------------------------------------------------------------
			-- => Tokyonight
			------------------------------------------------------------------------------------------------------------------------------
			-- NOTE: has to precede the color scheme settings
			vim.g.tokyonight_style = "storm"
			vim.g.tokyonight_sidebars = { "nerdtree", "terminal", "LuaTree", "sidebarnvim" }
			vim.g.tokyonight_hide_inactive_statusline = true
			vim.g.tokyonight_italic_comments = true
		end,
		config = function()
			-- THIS IS PURE FUCKING EVIL!!! DO NOT E-V-E-R SET THIS OPTION
			-- screws up all of the terminal colors, completely.
			-- going to leave it here is a reminder...
			-- OH HOW THINGS HAVE CHANGED)
			vim.opt.termguicolors = true

			vim.cmd("colorscheme solarized")

			-- Enable syntax highlighting
			vim.cmd("syntax enable")
			vim.g.background = "dark"
		end,
	})
	-- }}}

	-- git signs {{{
	use({
		"lewis6991/gitsigns.nvim",
		config = function()
			require("gitsigns").setup({
				on_attach = function(bufnr)
					local gs = package.loaded.gitsigns

					local function map(mode, l, r, opts)
						opts = opts or {}
						opts.buffer = bufnr
						vim.keymap.set(mode, l, r, opts)
					end

					-- Navigation
					map("n", "]c", "&diff ? ']c' : '<cmd>Gitsigns next_hunk<CR>'", { expr = true })
					map("n", "[c", "&diff ? '[c' : '<cmd>Gitsigns prev_hunk<CR>'", { expr = true })

					-- Actions
					map({ "n", "v" }, "<leader>hs", gs.stage_hunk)
					map({ "n", "v" }, "<leader>hr", gs.reset_hunk)
					map("n", "<leader>hS", gs.stage_buffer)
					map("n", "<leader>hu", gs.undo_stage_hunk)
					map("n", "<leader>hR", gs.reset_buffer)
					map("n", "<leader>hp", gs.preview_hunk)
					map("n", "<leader>hb", function()
						gs.blame_line({ full = true })
					end)
					map("n", "<leader>ht", gs.toggle_current_line_blame)
					map("n", "<leader>hd", gs.diffthis)
					map("n", "<leader>hD", function()
						gs.diffthis("~")
					end)
					map("n", "<leader>htd", gs.toggle_deleted)

					-- Text object
					map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>")
				end,
			})
		end,
	})
	-- }}}

	-- Focused writing {{{
	use({ "junegunn/goyo.vim" })
	use({
		"junegunn/limelight.vim",
		requires = { "junegunn/goyo.vim" },
		config = function()
			local utils = require("dsych_config.utils")
			vim.g.limelight_conceal_ctermfg = 240

			local zen_mode = false
			local function toggle_zen()
				if zen_mode then
					-- Disable zen mode
					zen_mode = 0
					utils.ToggleRelativeNumbers(true)
					vim.cmd("Goyo!")
					vim.cmd("Limelight!")
				else
					-- Enable zen mode
					zen_mode = true
					utils.ToggleRelativeNumbers(false)
					vim.cmd("Goyo")
					vim.cmd("Limelight")
				end
			end
			vim.api.nvim_add_user_command("Zen", toggle_zen, {})
		end,
	})
	-- }}}

	-- testing framework {{{
	use({
		"vim-test/vim-test",
		config = function()
			local map_key = require("dsych_config.utils").map_key

			map_key("n", "<leader>in", "<cmd>execute('TestNearest '.g:test_extra_flags)")
			map_key("n", "<leader>if", "<cmd>execute('TestFile '.g:test_extra_flags)")
			map_key("n", "<leader>is", "<cmd>execute('TestSuite '.g:test_extra_flags)")
			map_key("n", "<leader>il", "<cmd>execute('TestLast '.g:test_extra_flags)")
			map_key("n", "<leader>ig", "<cmd>execute('TestVisit '.g:test_extra_flags)")
			-- for maven set to something like this:
			--  -Dtests.additional.jvmargs=--'-Xdebug -Xrunjdwp:transport=dt_socket,address=localhost:5005,server=y,suspend=y'--
			-- for gradle use:
			--  --debug-jvm
			vim.g.test_debug_flags = ""
			vim.g.test_extra_flags = ""
			map_key("n", "<leader>idf", function()
				vim.g.test_debug_flags = ""
			end)
			map_key("n", "<leader>ie", function()
				vim.g.test_debug_flags = ""
			end)
			map_key("n", "<leader>id", "<cmd>execute('TestNearest '.g:test_extra_flags.' '.g:test_debug_flags)")
			map_key("n", "<leader>ids", "<cmd>execute('TestSuite '.g:test_extra_flags.' '.g:test_debug_flags)")

			vim.g["test#strategy"] = "neovim"
		end,
	})
	-- }}}

	-- indent guides {{{
	use({
		"lukas-reineke/indent-blankline.nvim",
		config = function()
			require("indent_blankline").setup({
				space_char_blankline = " ",
				show_current_context = true,
				use_treesitter = true,
				buftype_exclude = { "help", "nerdtree", "startify", "LuaTree", "Telescope*", "terminal" },
				show_first_indent_level = false,
				context_patterns = { "class", "function", "method", "expression", "statement" },
			})
		end,
	})
	-- }}}

	-- status line {{{
	use({
		-- FIXME: once change are upstreamed, change back
		"dsych/galaxyline.nvim",
		branch = "bugfix/diagnostics",
		-- Plug 'glepnir/galaxyline.nvim' , {'branch': 'main'}
		config = require("dsych_config.plugins.galaxyline").setup,
	})
	-- }}}

	-- git diff view {{{
	use({
		"sindrets/diffview.nvim",
		config = function()
			require("diffview").setup()

			vim.cmd([[
            augroup file_types
                autocmd!
                autocmd BufRead,BufNewFile *.json set filetype=jsonc
                autocmd BufRead,BufNewFile *sqc,*HPP,*CPP set filetype=cpp
            augroup END
            ]])
		end,
	})
	-- }}}

	-- literate movements and surround {{{
	use({ "tpope/vim-surround" })

	use({
		"justinmk/vim-sneak",

		config = function()
			local map_key = require("dsych_config.utils").map_key
			-- remap default keybindings to sneak
			map_key("n", "f", "<Plug>Sneak_f")
			map_key("n", "F", "<Plug>Sneak_F")
			map_key("n", "t", "<Plug>Sneak_t")
			map_key("n", "T", "<Plug>Sneak_T")
		end,
	})
	-- }}}

	-- terminal {{{
	use({
		"akinsho/nvim-toggleterm.lua",
		config = function()
			local map_key = require("dsych_config.utils").map_key

			require("toggleterm").setup({
				open_mapping = [[<c-\>]],
			})
			-- turn terminal to normal mode with escape
			map_key("t", "<Esc>", "<C-\\><C-n>")
			-- start terminal in insert mode
			-- and do not show terminal buffers in buffer list
			vim.cmd([[
            augroup terminal
                autocmd!
                autocmd TermOpen * setlocal nobuflisted
                " au BufEnter * if &buftype == 'terminal' | :startinsert | endif
            augroup END
            ]])
		end,
	})
	-- }}}

	-- treesitter syntax highlighting and more {{{
	use({
		"nvim-treesitter/nvim-treesitter",
		run = ":TSUpdate",
		config = function()
			require("nvim-treesitter.configs").setup({
				ensure_installed = "maintained",
				indent = {
					enable = true,
				},
				highlight = {
					enable = true,
					additional_vim_regex_highlighting = false,
				},
			})
		end,
	})
	-- }}}

	-- intelligent comments based on treesitter {{{
	use({
		"JoosepAlviste/nvim-ts-context-commentstring",
		requires = { "nvim-treesitter/nvim-treesitter" },
		config = function()
			require("nvim-treesitter.configs").setup({
				context_commentstring = {
					enable = true,
					autocmd = false,
				},
			})
		end,
	})
	-- }}}

	-- additional text objects based on treesitter {{{
	use({
		"nvim-treesitter/nvim-treesitter-textobjects",
		requires = { "nvim-treesitter/nvim-treesitter" },
		config = function()
			require("nvim-treesitter.configs").setup({
				textobjects = {
					select = {
						enable = true,

						-- Automatically jump forward to textobj, similar to targets.vim
						lookahead = true,

						keymaps = {
							-- You can use the capture groups defined in textobjects.scm
							["af"] = "@function.outer",
							["if"] = "@function.inner",
							["ac"] = "@class.outer",
							["ic"] = "@class.inner",
							["ia"] = "@parameter.inner",
							["aa"] = "@parameter.outer",
						},
					},
					move = {
						enable = true,
						set_jumps = true, -- whether to set jumps in the jumplist
						goto_next_start = {
							["]m"] = "@function.outer",
							["]]"] = "@class.outer",
							["]a"] = "@parameter.inner",
						},
						goto_previous_start = {
							["[m"] = "@function.outer",
							["[["] = "@class.outer",
							["[a"] = "@parameter.inner",
						},
					},
				},
			})
		end,
	})
	-- }}}

	-- hocon filetype {{{
	use({
		"satabin/hocon-vim",
	})
	-- }}}

	-- markdown preview {{{
	use({
		-- depends on https://github.com/charmbracelet/glow
		"ellisonleao/glow.nvim",
	})
	-- }}}

	-- search and replace inside quickfix window {{{
	use({
		"gabrielpoca/replacer.nvim",
		config = function()
			local map_key = require("dsych_config.utils").map_key
			map_key("n", "<leader>rq", require("replacer").run)
		end,
	})
	-- }}}

	-- coverage guide {{{
	use({
		"dsych/blanket.nvim",
	})
	-- }}}

	-- enhance vim's native spell checker {{{
	use({
		"dsych/vim-spell",
		config = function()
			vim.cmd([[
                augroup code_spell
                    autocmd!
                    " turn on spell checking for all file types
                    autocmd FileType * :set spelloptions=camel | :set spellcapcheck= | :set spell
                    " except for the following file types
                    " vim ft has poor dictionary
                    autocmd FileType startify,vim,Telescope*,help :set nospell
                augroup end
            ]])
		end,
	})
	-- }}}

	-- Automatically set up your configuration after cloning packer.nvim
	-- Put this at the end after all plugins
	if packer_bootstrap then
		require("packer").sync()
	end
end)
