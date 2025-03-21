local M = {}

local get_current_visual_selection = function ()
    local get_line_and_col_for_mark = function (mark)
        local ret = vim.fn.getpos("'" .. mark)
        return ret[2], ret[3]
    end

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), 'x', false)

    local line_start, column_start = get_line_and_col_for_mark("<")
    local line_end, column_end = get_line_and_col_for_mark(">")
    return { start = { line_start, column_start }, ["end"] = { line_end, column_end } }
end

local filetype_to_default_formatter = {
	["typescript"] = "null-ls",
	["java"] = "jdtls",
	["python"] = "ruff"
}

local select_lsp_client = function(callback)
    local client_names = vim.tbl_map(function (client) return client.name end, vim.lsp.get_clients())
	local filetype = vim.bo.filetype

    if vim.tbl_count(client_names) < 1 then
        return
    elseif vim.tbl_count(client_names) == 1  then
        callback(client_names[1])
	elseif filetype_to_default_formatter[filetype] ~= nil then
		callback(filetype_to_default_formatter[filetype])
    else
        vim.ui.select(client_names, {prompt = "Which lsp client:" }, function(choice)
            if choice ~= nil then
                callback(choice)
            end
        end)
    end
end

M.mk_config = function()
	local capabilities = vim.lsp.protocol.make_client_capabilities()
	capabilities.workspace.configuration = true
	capabilities.textDocument.completion.completionItem.snippetSupport = true
    -- FIXME: workaround for high cpu usage in the recent nighty release because of the new file watcher
	capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = false
    vim.diagnostic.config({
        virtual_text = false,
        severity_sort = true,
        float = {
            source = "always"
        }
    })
    local c = vim.tbl_extend("force", require('cmp_nvim_lsp').default_capabilities(), capabilities)
	return {
		flags = {
			allow_incremental_sync = true,
		},
		["capabilities"] = c,
		-- on_init = function(client)
		-- 	client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
		-- end,
	}
end

M.define_mappings = function()
	local map_key = require("dsych_config.utils").map_key
	local utils = require("dsych_config.utils")
    local pick_win = require("window-picker").pick_window

	-- See `:help vim.lsp.*` for documentation on any of the below functions
	map_key("n", "gD", require("telescope.builtin").lsp_type_definitions)
	map_key("n", "gd", require("telescope.builtin").lsp_definitions)
	map_key("n", "gds", function()
		vim.cmd.split()
		vim.lsp.buf.definition()
	end)
	map_key("n", "gdv", function()
		vim.cmd.vsplit()
		vim.lsp.buf.definition()
	end)
    map_key("n", "gdw", function()
        local current_buffer_nr = vim.api.nvim_win_get_buf(0)
        local current_line_coords = vim.api.nvim_win_get_cursor(0)
        local win_id = pick_win()
        if win_id == nil then
            return
        end
        vim.fn.win_gotoid(win_id)
        vim.api.nvim_win_set_buf(win_id, current_buffer_nr)
        vim.api.nvim_win_set_cursor(win_id, current_line_coords)
        vim.lsp.buf.definition()
    end)
	map_key("n", "gdp", "<c-w>}")
	map_key("n", "gdc", "<c-w>z")
	map_key("n", "gi", require("telescope.builtin").lsp_implementations)
	map_key("n", "grn", vim.lsp.buf.rename)

	map_key("n", "gs", function () require("telescope.builtin").lsp_document_symbols({ fname_width = 50, symbol_width = 50 }) end)
	map_key("n", "gS", require("telescope.builtin").lsp_dynamic_workspace_symbols)
	map_key("n", "K", utils.show_documentation)
	map_key({ "n", "i" }, "<C-Y>", vim.lsp.buf.signature_help)
	map_key("n", "gr", require("telescope.builtin").lsp_references)
	map_key("n", "gci", require("telescope.builtin").lsp_incoming_calls)
	map_key("n", "gco", require("telescope.builtin").lsp_outgoing_calls)

	map_key("n", "<leader>wa", vim.lsp.buf.add_workspace_folder)
	map_key("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder)
	map_key("n", "<leader>wl", function()
		print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
	end)

	map_key({ "n", "v", "x" }, "ga", vim.lsp.buf.code_action)

	map_key("n", "<leader>de", function()
		require("telescope.builtin").diagnostics({ bufnr = nil, severity = "ERROR" })
	end)
	map_key("n", "<leader>dd", function()
		require("telescope.builtin").diagnostics({ bufnr = nil })
	end)
	map_key("n", "[d", vim.diagnostic.goto_prev)
	map_key("n", "]d", vim.diagnostic.goto_next)
	map_key("n", "[e", function()
		vim.diagnostic.goto_prev({ severity = "Error" })
	end)
	map_key("n", "]e", function()
		vim.diagnostic.goto_next({ severity = "Error" })
	end)

    map_key("n", "<M-F>", function()
        select_lsp_client(function (desired_client)
            vim.lsp.buf.format({ timeout_ms = 10000, async = false, name = desired_client })
        end)
    end)

    map_key({ "v", "x" }, "<M-F>", function()
        local r = get_current_visual_selection()
        select_lsp_client(function (desired_client)
            vim.lsp.buf.format({ timeout_ms = 10000, async = false, name = desired_client, range = r })
        end)
    end)

	vim.api.nvim_create_user_command("LspFormat", function ()
        select_lsp_client(function (desired_client)
            vim.lsp.buf.format({ timeout_ms = 10000, async = false, name = desired_client })
        end)
	end, {
        force = true,
        desc = "Formats the current buffer, if there are any lsp clients attached. If more than one client is found, allows to pick which one.",
    })
end

M.configure_lsp = function(lsp_opts)
	lsp_opts = lsp_opts or {}

	require("dsych_config.lsp.utils").define_mappings()

	local old_on_attach = lsp_opts.on_attach
	lsp_opts.on_attach = function(client, bufnr)
		if old_on_attach then
			old_on_attach(client, bufnr)
		end

		--   if client.resolved_capabilities.document_highlight then
		--       vim.cmd [[
		--         hi! LspReferenceRead cterm=bold ctermbg=red guibg=#eee8d5
		--         hi! LspReferenceText cterm=bold ctermbg=red guibg=#eee8d5
		--         hi! LspReferenceWrite cterm=bold ctermbg=red guibg=#eee8d5
		--         augroup lsp_document_highlight
		--           autocmd! * <buffer>
		--           autocmd! CursorHold <buffer> lua vim.lsp.buf.document_highlight()
		--           autocmd! CursorMoved <buffer> lua vim.lsp.buf.clear_references()
		--         augroup END
		--       ]]
		--   end
	end

	vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
	  vim.lsp.handlers.hover, {
		-- Use a sharp border with `FloatBorder` highlights
		border = "single",
	  }
	)

	return lsp_opts
end

return M
