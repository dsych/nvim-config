local M = {}
M.mk_config = function()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.workspace.configuration = true
  capabilities.textDocument.completion.completionItem.snippetSupport = true

  return {
    flags = {
      allow_incremental_sync = true,
    };
    handlers = {
      ["textDocument/publishDiagnostics"] = vim.lsp.with(
        vim.lsp.diagnostic.on_publish_diagnostics, {
           -- Enable underline, use default values
           underline = true,
           -- Enable virtual text, override spacing to 4
           virtual_text = {
             spacing = 4,
           },
           -- Disable a feature
           update_in_insert = false,
        }
    ),
  };
    capabilities = capabilities;
    on_init = (function(client)
      client.notify('workspace/didChangeConfiguration', { settings = client.config.settings })
    end)
  }
end

M.define_mappings = function()
  local map_key = require'dsych_config.utils'.map_key
  local utils = require'dsych_config.utils'
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  map_key('n', 'gD', vim.lsp.buf.declaration)
  map_key('n', 'gd', require"telescope.builtin".lsp_definitions)
  map_key('n', 'gds', function() vim.cmd("split"); vim.lsp.buf.definition() end)
  map_key('n', 'gdv', function() vim.cmd("vsplit"); vim.lsp.buf.definition() end)
  map_key('n', 'gi', require"telescope.builtin".lsp_implementations)
  map_key('n', 'grn', vim.lsp.buf.rename)

  map_key('n', 'gs', require"telescope.builtin".lsp_document_symbols)
  map_key('n', 'gS', require"telescope.builtin".lsp_dynamic_workspace_symbols)
  map_key('n', 'K', utils.show_documentation)
  map_key({ 'n', 'i' }, '<C-Y>', vim.lsp.buf.signature_help)
  map_key('n', 'gr', require"telescope.builtin".lsp_references)
  map_key('n', 'gci', vim.lsp.buf.incoming_calls)
  map_key('n', 'gco', vim.lsp.buf.outgoing_calls)

  map_key('n', '<leader>wa', vim.lsp.buf.add_workspace_folder)
  map_key('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder)
  map_key('n', '<leader>wl', function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end)

  map_key('n', 'ga', vim.lsp.buf.code_action)

  map_key('n', '<leader>de', function() require"telescope.builtin".diagnostics({bufnr = nil, severity = "ERROR"}) end)
  map_key('n', '<leader>dd', function() require"telescope.builtin".diagnostics({bufnr = nil}) end)
  map_key('n', '[d', vim.diagnostic.goto_prev)
  map_key('n', ']d', vim.diagnostic.goto_next)
  map_key('n', '[e', function() vim.diagnostic.goto_prev({severity = "Error"}) end)
  map_key('n', ']e', function() vim.diagnostic.goto_next({severity = "Error"}) end)

  map_key('n', '<M-F>', vim.lsp.buf.formatting)
  map_key({ 'v', 'x' }, '<M-F>', vim.lsp.buf.range_formatting)
end

M.configure_lsp = function(lsp_opts)
  lsp_opts = lsp_opts or {}

  local lsp_status = require'lsp-status'
  lsp_status.register_progress()

  require'dsych_config.lsp.utils'.define_mappings()

  local old_on_attach = lsp_opts.on_attach
  lsp_opts.on_attach = function(client, bufnr)
    lsp_status.on_attach(client)

    require"lsp_signature".on_attach({
        hint_prefix = "⇵",
        floating_window = false,
    })

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

  return coq.lsp_ensure_capabilities(lsp_opts)
end

return M