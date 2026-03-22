local ESX = exports["es_extended"]:getSharedObject()
local machineZones = {} -- Ahora guardamos las zonas invisibles, no NPCs

local function CreateDesignMenu(machineId)
    local input = lib.inputDialog('Nuevo Diseño', {
        {type = 'select', label = 'Tipo de Objeto', options = {{value='Movil', label='Móvil'}, {value='Tablet', label='Tablet'}, {value='Radio', label='Radio'}, {value='Bloc', label='Bloc'}}, required = true},
        {type = 'input', label = 'Nombre Personalizado', required = true},
        {type = 'textarea', label = 'Descripción', required = true}
    })
    if not input then return end
    lib.notify({title = 'Paso 2', description = 'Por favor, pega tu imagen con Ctrl+V', type = 'inform'})
    exports['nebula_imghost']:OpenUploader(function(url)
        if url then 
            TriggerServerEvent('custom_items:submitForReview', {type=input[1], label=input[2], description=input[3], imageurl=url, machineId=machineId}) 
            lib.notify({title='Enviado', type='success'})
        else 
            lib.notify({title='Cancelado', type='error'}) 
        end
    end)
end

local function OpenBossMenu(jobName)
    ESX.TriggerServerCallback('custom_items:getJobGrades', function(grades)
        local options = {}
        for i=1, #grades do
            local g = grades[i]
            table.insert(options, {
                title = g.label .. ' (Rango ' .. g.grade .. ')',
                description = 'Gestionar permisos para todos los ' .. g.label,
                icon = 'users',
                onSelect = function()
                    local input = lib.inputDialog('Permisos: ' .. g.label, {
                        {type = 'checkbox', label = 'Pueden Enviar Diseños', checked = g.can_submit == 1},
                        {type = 'checkbox', label = 'Pueden Fabricar Objetos', checked = g.can_craft == 1},
                        {type = 'checkbox', label = 'Pueden Borrar Diseños', checked = g.can_delete == 1}
                    })
                    if input then
                        TriggerServerEvent('custom_items:updatePerms', jobName, g.grade, input[1], input[2], input[3])
                    end
                end
            })
        end
        lib.registerContext({id = 'boss_perm_menu', title = 'Gestión de Permisos ('..jobName..')', menu = 'user_main_menu', options = options})
        lib.showContext('boss_perm_menu')
    end, jobName)
end

-- Ahora recibe el trabajo y la id directamente en lugar de la entidad
local function OpenMainMenu(reqJob, machineId)
    if not lib then return end
    reqJob = reqJob or "all"
    machineId = machineId or 0
    
    if reqJob ~= "all" and ESX.GetPlayerData().job.name ~= reqJob then
        lib.notify({title = 'Acceso Denegado', description = 'Máquina exclusiva para: ' .. string.upper(reqJob), type = 'error'})
        return
    end

    ESX.TriggerServerCallback('custom_items:getMenuData', function(approved, pending, perms, isBoss)
        local options = {}

        if isBoss then table.insert(options, {title = 'Panel de Jefe', description = 'Gestionar permisos por rangos', icon = 'briefcase', onSelect = function() OpenBossMenu(reqJob) end}) end

        if perms.submit then table.insert(options, {title = 'Crear nuevo diseño', description = 'Envía un boceto para revisión', icon = 'plus', onSelect = function() CreateDesignMenu(machineId) end})
        else table.insert(options, {title = 'Crear nuevo diseño', description = 'El Jefe ha bloqueado esta función.', icon = 'lock', disabled = true}) end

        if #approved > 0 then
            local appMenu = {}
            for i=1, #approved do
                local d = approved[i]
                local subOptions = {}
                if perms.craft then table.insert(subOptions, {title = 'Fabricar Objeto', icon = 'hammer', onSelect = function() TriggerServerEvent('custom_items:craftMyDesign', d.id) end}) end
                if perms.delete then table.insert(subOptions, {title = 'Eliminar Diseño', icon = 'trash', iconColor = '#f56565', onSelect = function() TriggerServerEvent('custom_items:deleteMyDesign', d.id) end}) end
                
                if #subOptions > 0 then
                    table.insert(appMenu, {title = d.custom_label, description = d.item_type, icon = 'check-circle', onSelect = function() lib.registerContext({id = 'action_'..d.id, title = d.custom_label, menu = 'app_des', options = subOptions}); lib.showContext('action_'..d.id) end})
                end
            end
            if #appMenu > 0 then
                lib.registerContext({id = 'app_des', title = 'Aprobados', menu = 'user_main_menu', options = appMenu})
                table.insert(options, {title = 'Utilizar diseño creado', icon = 'palette', menu = 'app_des'})
            end
        end

        if #pending > 0 then
            local penMenu = {}
            for i=1, #pending do
                local p = pending[i]
                table.insert(penMenu, {
                    title = p.custom_label, description = 'Esperando revisión...', icon = 'clock',
                    onSelect = function()
                        if perms.delete then
                            lib.registerContext({id = 'can_'..p.id, title = 'Cancelar: ' .. p.custom_label, menu = 'pen_des', options = {{title = 'Cancelar Diseño', icon = 'trash', iconColor = '#f56565', onSelect = function() TriggerServerEvent('custom_items:deleteMyDesign', p.id) end}}})
                            lib.showContext('can_'..p.id)
                        else lib.notify({title='Bloqueado', description='No tienes permiso para borrar.', type='error'}) end
                    end
                })
            end
            lib.registerContext({id = 'pen_des', title = 'Pendientes', menu = 'user_main_menu', options = penMenu})
            table.insert(options, {title = 'Diseños pendientes', icon = 'hourglass-half', menu = 'pen_des'})
        end

        lib.registerContext({id = 'user_main_menu', title = 'Mesa de Personalización', options = options})
        lib.showContext('user_main_menu')
    end, reqJob, machineId)
end

-- Este evento ahora recibe las coordenadas exactas del objeto que miró el admin
RegisterNetEvent('custom_items:openMachineCreator', function(coords)
    local input = lib.inputDialog('Crear Máquina', {{
        type = 'input', 
        label = 'Trabajo Permitido', 
        placeholder = 'Ej: police, ambulance, all', -- Texto de ayuda que desaparece al escribir
        required = true
    }})
    if input then TriggerServerEvent('custom_items:saveNewMachine', string.lower(input[1]), coords) end
end)

-- Esta función crea la zona invisible en las coordenadas guardadas
local function CreateMachineZone(id, d)
    if machineZones[id] then return end
    
    local zoneId = exports.ox_target:addSphereZone({
        coords = vec3(d.x, d.y, d.z),
        radius = 1.2, -- Radio de la zona donde se puede hacer ALT
        debug = false, -- Ponlo en true si quieres ver la zona invisible para probar
        options = {
            {
                name = 'machine_use_'..id,
                icon = 'fas fa-paint-brush',
                label = 'Mesa de Personalización',
                onSelect = function() OpenMainMenu(d.job, id) end
            },
            {
                name = 'machine_del_'..id,
                icon = 'fas fa-trash',
                label = 'Eliminar Máquina (Admin)',
                canInteract = function()
                    local playerData = ESX.GetPlayerData()
                    return playerData and (playerData.group == 'admin' or playerData.group == 'superadmin')
                end,
                onSelect = function()
                    TriggerServerEvent('custom_items:deleteSingleMachine', id)
                end
            }
        }
    })
    
    machineZones[id] = zoneId
end

RegisterNetEvent('custom_items:receiveMachines', function(machines)
    for i=1, #(machines or {}) do
        local d = json.decode(machines[i].coords)
        if d and d.x then CreateMachineZone(machines[i].id, d) end
    end
end)
RegisterNetEvent('custom_items:spawnNewPedInstant', function(data) CreateMachineZone(data.id, data.coords) end)

RegisterNetEvent('custom_items:removeSingleMachine', function(id)
    if machineZones[id] then
        exports.ox_target:removeZone(machineZones[id])
        machineZones[id] = nil
    end
end)

RegisterNetEvent('custom_items:deleteAllMachines', function() 
    for id, zoneId in pairs(machineZones) do 
        exports.ox_target:removeZone(zoneId) 
    end 
    machineZones = {} 
end)

CreateThread(function()
    while ESX == nil do Wait(100) end
    TriggerServerEvent('custom_items:requestMachines')
    
    -- Opción global para que los admins miren a OBJETOS del entorno (imprentas, mesas...) y creen la máquina ahí
    exports.ox_target:addGlobalObject({
        {
            name = 'onx_create_machine_admin',
            icon = 'fas fa-plus-circle',
            label = 'Crear Máquina aquí (Admin)',
            canInteract = function(entity, distance, coords, name, bone)
                local playerData = ESX.GetPlayerData()
                if playerData and (playerData.group == 'admin' or playerData.group == 'superadmin') then
                    return true
                end
                return false
            end,
            onSelect = function(data)
                -- Obtenemos las coordenadas exactas del objeto que hemos mirado
                local objCoords = GetEntityCoords(data.entity)
                TriggerEvent('custom_items:openMachineCreator', objCoords)
            end
        }
    })
end)

RegisterNetEvent('custom_items:openAdminMenu', function(items)
    if not lib then return end
    local options = {}
    
    for i=1, #items do
        local d = items[i]
        local dData = json.decode(d.design_data)
        
        local machineJob = "Desconocido"
        if d.machine_coords then
            local coordsData = json.decode(d.machine_coords)
            if coordsData and coordsData.job then
                machineJob = coordsData.job
            end
        end
        
        local descText = string.format("Tipo: %s | Máquina ID: %s | Trabajo: %s", d.item_type, d.machine_id, string.upper(machineJob))

        table.insert(options, {
            title = d.custom_label, 
            description = descText, 
            icon = 'magnifying-glass',
            onSelect = function()
                lib.registerContext({id='rev_'..d.id, title=d.custom_label, menu='adm', options={
                    {title='Trabajo asignado: ' .. string.upper(machineJob), icon='briefcase', readOnly=true},
                    {title='Vista Previa', image=dData.imageurl, readOnly=true},
                    {title='Aprobar', icon='check', iconColor='#48bb78', onSelect=function() TriggerServerEvent('custom_items:processDesign', d.id, 'approved') end},
                    {title='Denegar', icon='x', iconColor='#f56565', onSelect=function() TriggerServerEvent('custom_items:processDesign', d.id, 'denied') end}
                }})
                lib.showContext('rev_'..d.id)
            end
        })
    end
    
    lib.registerContext({id = 'adm', title = 'Diseños Pendientes', options = options})
    lib.showContext('adm')
end)