local QBCore = exports['qb-core']:GetCoreObject()

RegisterServerEvent('rw_hud:getServerInfo')
AddEventHandler('rw_hud:getServerInfo', function()
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player then
        return -- Exit if Player is not valid
    end

    Citizen.Wait(100)

    local info = {
        money = Player.PlayerData.money.cash or 0,
        bank = Player.PlayerData.money.bank or 0,
        blackm = Player.PlayerData.money.crypto or 0,
        dnates = Player.PlayerData.money.donate or 0,
    }

    TriggerClientEvent('rw_hud:setInfo', source, info)
end)

--- Stress ---

local ResetStress = false

RegisterNetEvent('hud:server:GainStress', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return -- Exit if Player is not valid
    end

    local newStress
    if not Player or (Config.DisablePoliceStress and Player.PlayerData.job.name == 'police') then return end
    if not ResetStress then
        if not Player.PlayerData.metadata['stress'] then
            Player.PlayerData.metadata['stress'] = 0
        end
        newStress = Player.PlayerData.metadata['stress'] + amount
        if newStress <= 0 then newStress = 0 end
    else
        newStress = 0
    end
    if newStress > 100 then
        newStress = 100
    end
    Player.Functions.SetMetaData('stress', newStress)
    TriggerClientEvent('hud:client:UpdateStress', src, newStress)
    TriggerClientEvent('QBCore:Notify', src, Lang:t("notify.stress_gain"), 'error', 1500)
end)

RegisterNetEvent('hud:server:RelieveStress', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return -- Exit if Player is not valid
    end

    local newStress
    if not ResetStress then
        if not Player.PlayerData.metadata['stress'] then
            Player.PlayerData.metadata['stress'] = 0
        end
        newStress = Player.PlayerData.metadata['stress'] - amount
        if newStress <= 0 then newStress = 0 end
    else
        newStress = 0
    end
    if newStress > 100 then
        newStress = 100
    end
    Player.Functions.SetMetaData('stress', newStress)
    TriggerClientEvent('hud:client:UpdateStress', src, newStress)
    TriggerClientEvent('QBCore:Notify', src, Lang:t("notify.stress_removed"))
end)
