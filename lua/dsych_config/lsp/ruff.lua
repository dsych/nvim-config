return function (config)
    local old_on_attach = config.on_attah


    config.on_attach = function (client, buffer)
        client.server_capabilities.hoverProvider = false
        if old_on_attach then
            old_on_attach(client, buffer)
        end
    end

    return config
end
