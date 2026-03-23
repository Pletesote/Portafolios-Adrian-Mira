local ESX = exports["es_extended"]:getSharedObject()

ESX.RegisterCommand('dev', 'admin', function(xPlayer, args, showError)
    -- Leemos el estado actual del jugador (por defecto false)
    local currentState = Player(xPlayer.source).state.isDevMode or false
    
    -- Lo cambiamos al contrario (si era true pasa a false, y viceversa)
    -- El 'true' al final sincroniza esta variable con todos los clientes
    Player(xPlayer.source).state:set('isDevMode', not currentState, true)
    
    -- Enviamos la notificación visual
    TriggerClientEvent('nebula_devmode:notify', xPlayer.source, not currentState)
end, false, {help = 'Activar/Desactivar opciones de desarrollador'})