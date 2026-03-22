local ESX = exports["es_extended"]:getSharedObject()

local itemMap = {
    ['Radio']  = { base = 'radio', custom = 'custom_radio' },
    ['Movil']  = { base = 'phone', custom = 'custom_phone' },
    ['Tablet'] = { base = 'tablet', custom = 'custom_tablet' },
    ['Bloc']   = { base = 'notepad', custom = 'custom_notepad' }
}

ESX.RegisterCommand('diseños', 'admin', function(xPlayer)
    MySQL.Async.fetchAll([[
        SELECT p.*, m.coords AS machine_coords 
        FROM custom_items_pending p
        LEFT JOIN custom_machines m ON p.machine_id = m.id
        WHERE p.status = "pending"
    ]], {}, function(pending)
        if pending and #pending > 0 then 
            TriggerClientEvent('custom_items:openAdminMenu', xPlayer.source, pending)
        else 
            xPlayer.showNotification("No hay diseños pendientes.") 
        end
    end)
end, false)

ESX.RegisterCommand('borrarmaquinas', 'admin', function(xPlayer)
    MySQL.Async.execute('DELETE FROM custom_machines', {}, function(rows)
        if rows > 0 then 
            xPlayer.showNotification("Todas las máquinas han sido borradas.") 
            TriggerClientEvent('custom_items:deleteAllMachines', -1) 
        end
    end)
end, false)

-- Recibe las coordenadas que el admin envió desde el cliente
RegisterNetEvent('custom_items:saveNewMachine', function(jobName, coords)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or (xPlayer.getGroup() ~= 'admin' and xPlayer.getGroup() ~= 'superadmin') then return end
    
    -- Solo necesitamos x, y, z y el trabajo
    local coordsTable = {x = coords.x, y = coords.y, z = coords.z, job = jobName}
    
    MySQL.Async.insert('INSERT INTO custom_machines (coords) VALUES (@coords)', {['@coords'] = json.encode(coordsTable)}, function(id)
        if id > 0 then 
            xPlayer.showNotification("Máquina vinculada al objeto. Acceso: " .. jobName) 
            TriggerClientEvent('custom_items:spawnNewPedInstant', -1, {id = id, coords = coordsTable}) 
        end
    end)
end)

RegisterNetEvent('custom_items:deleteSingleMachine', function(machineId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or (xPlayer.getGroup() ~= 'admin' and xPlayer.getGroup() ~= 'superadmin') then return end

    MySQL.Async.execute('DELETE FROM custom_machines WHERE id = @id', {['@id'] = machineId}, function(rows)
        if rows > 0 then
            xPlayer.showNotification("Máquina eliminada correctamente.")
            TriggerClientEvent('custom_items:removeSingleMachine', -1, machineId)
        end
    end)
end)

RegisterNetEvent('custom_items:requestMachines', function()
    local _source = source
    MySQL.Async.fetchAll('SELECT * FROM custom_machines', {}, function(machines) TriggerClientEvent('custom_items:receiveMachines', _source, machines or {}) end)
end)

ESX.RegisterServerCallback('custom_items:getMenuData', function(source, cb, reqJob, machineId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb({}, {}, {}, false) return end

    local isBoss = (xPlayer.job.name == reqJob and xPlayer.job.grade_name == 'boss')
    local perms = {submit = false, craft = false, delete = false}

    if reqJob == 'all' or isBoss then
        perms = {submit = true, craft = true, delete = true}
    else
        local pData = MySQL.Sync.fetchAll('SELECT * FROM custom_items_perms WHERE job = @job AND grade = @grade', {['@job'] = reqJob, ['@grade'] = xPlayer.job.grade})
        if pData[1] then
            perms = {submit = pData[1].can_submit == 1, craft = pData[1].can_craft == 1, delete = pData[1].can_delete == 1}
        end
    end

    MySQL.Async.fetchAll('SELECT * FROM custom_items_pending WHERE identifier = @id AND machine_id = @machineId', {
        ['@id'] = xPlayer.identifier, 
        ['@machineId'] = machineId
    }, function(results)
        local approved, pending = {}, {}
        for i=1, #results do
            if results[i].status == 'approved' then table.insert(approved, results[i])
            elseif results[i].status == 'pending' then table.insert(pending, results[i]) end
        end
        cb(approved, pending, perms, isBoss)
    end)
end)

ESX.RegisterServerCallback('custom_items:getJobGrades', function(source, cb, jobName)
    local grades = MySQL.Sync.fetchAll([[
        SELECT g.grade, g.label, p.can_submit, p.can_craft, p.can_delete 
        FROM job_grades g 
        LEFT JOIN custom_items_perms p ON g.job_name = p.job AND g.grade = p.grade 
        WHERE g.job_name = @job
        ORDER BY g.grade ASC
    ]], {['@job'] = jobName})
    cb(grades)
end)

RegisterNetEvent('custom_items:updatePerms', function(jobName, grade, submit, craft, delete)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.job.name == jobName and xPlayer.job.grade_name == 'boss' then
        MySQL.Async.execute([[
            INSERT INTO custom_items_perms (job, grade, can_submit, can_craft, can_delete) 
            VALUES (@job, @grade, @sub, @crf, @del) 
            ON DUPLICATE KEY UPDATE can_submit=@sub, can_craft=@crf, can_delete=@del
        ]], {
            ['@job'] = jobName, ['@grade'] = grade, 
            ['@sub'] = submit and 1 or 0, ['@crf'] = craft and 1 or 0, ['@del'] = delete and 1 or 0
        })
        xPlayer.showNotification("Permisos del rango actualizados.")
    end
end)

RegisterNetEvent('custom_items:submitForReview', function(data)
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.Async.execute('INSERT INTO custom_items_pending (identifier, machine_id, item_type, custom_label, custom_description, design_data) VALUES (@id, @machineId, @type, @label, @desc, @data)', {
        ['@id'] = xPlayer.identifier, 
        ['@machineId'] = data.machineId or 0,
        ['@type'] = data.type, 
        ['@label'] = data.label, 
        ['@desc'] = data.description, 
        ['@data'] = json.encode({imageurl = data.imageurl})
    })
end)

RegisterNetEvent('custom_items:craftMyDesign', function(designId)
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.Async.fetchAll('SELECT * FROM custom_items_pending WHERE id = @id AND identifier = @identifier AND status = "approved"', {['@id'] = designId, ['@identifier'] = xPlayer.identifier}, function(result)
        if result[1] then
            local mapping = itemMap[result[1].item_type]
            if xPlayer.getInventoryItem(mapping.base).count >= 1 then
                xPlayer.removeInventoryItem(mapping.base, 1)
                exports.ox_inventory:AddItem(xPlayer.source, mapping.custom, 1, {
                    label = result[1].custom_label, description = result[1].custom_description, image = json.decode(result[1].design_data).imageurl
                })
                xPlayer.showNotification("Objeto fabricado!")
            else xPlayer.showNotification("No tienes el objeto base.", "error") end
        end
    end)
end)

RegisterNetEvent('custom_items:deleteMyDesign', function(designId)
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.Async.execute('DELETE FROM custom_items_pending WHERE id = @id AND identifier = @identifier', {['@id'] = designId, ['@identifier'] = xPlayer.identifier})
end)

RegisterNetEvent('custom_items:processDesign', function(requestId, status)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getGroup() == 'admin' or xPlayer.getGroup() == 'superadmin' then
        MySQL.Async.execute('UPDATE custom_items_pending SET status = @status WHERE id = @id', {['@status'] = status, ['@id'] = requestId})
    end
end)