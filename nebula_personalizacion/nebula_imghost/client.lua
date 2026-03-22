local uploaderActive = false
local currentCallback = nil

-- Función para abrir el uploader (Activada por otros scripts mediante el export)
function OpenImageUploader(cb)
    -- Si ya está abierto, no hacemos nada para evitar bugs
    if uploaderActive then return end 
    
    uploaderActive = true
    currentCallback = cb -- Guardamos la función para devolverle la URL luego

    -- Mostramos la NUI y le damos el control del ratón y el teclado al jugador
    SetNuiFocus(true, true)
    
    -- Avisamos a Javascript (script.js) de que muestre la ventana
    SendNUIMessage({
        action = 'openUploader'
    })
end

-- EXPORT: Así exponemos la función para que tu script de radios la pueda usar
exports('OpenUploader', OpenImageUploader)

-- Callback que recibe la respuesta de Javascript cuando el jugador pega la foto o cancela
RegisterNUICallback('nebula_imghost:onComplete', function(data, cb)
    -- Quitamos el foco de la pantalla para que el jugador pueda volver a moverse
    SetNuiFocus(false, false)
    uploaderActive = false

    -- Si el script de las radios nos dejó una función esperando, se la enviamos
    if currentCallback then
        -- data.url contendrá el enlace de Discord, o será 'nil' si el jugador le dio a Cancelar
        currentCallback(data.url) 
        currentCallback = nil
    end

    -- Le decimos a Javascript que hemos recibido el mensaje correctamente
    cb('ok')
end)