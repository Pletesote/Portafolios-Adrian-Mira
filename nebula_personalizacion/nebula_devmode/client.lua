RegisterNetEvent('nebula_devmode:notify', function(status)
    if status then
        -- Notificación lateral
        lib.notify({
            title = 'Modo Developer', 
            description = 'Opciones de administración ACTIVADAS', 
            type = 'success', 
            icon = 'code'
        })
        
        -- Cajita persistente en la pantalla
        lib.showTextUI('[MODO DEV] Activo', {
            position = 'top-center',
            icon = 'code',
            style = {
                borderRadius = 5,
                backgroundColor = '#ef4444', -- Rojo para destacar
                color = 'white',
                fontWeight = 'bold'
            }
        })
    else
        -- Notificación lateral
        lib.notify({
            title = 'Modo Developer', 
            description = 'Opciones de administración DESACTIVADAS', 
            type = 'error', 
            icon = 'code'
        })
        
        -- Ocultamos la cajita de la pantalla
        lib.hideTextUI()
    end
end)