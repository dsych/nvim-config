return function (config)
    local old_on_attach = config.on_attah


    config.on_attach = function (client, buffer)
        client.handlers["textDocument/publishDiagnostics"] = function(_, result, ctx, diag_config)
            result.diagnostics = vim.tbl_filter(function (diagnostic)
                -- disabled diagnostics related to undefined steps as it's a class path issue
                return string.gmatch(diagnostic.message, "Undefined step:")() == nil
            end, result.diagnostics)

            vim.lsp.diagnostic.on_publish_diagnostics(_, result, ctx, diag_config)
        end

        if old_on_attach then
            old_on_attach(client, buffer)
        end
    end

    return config
end
