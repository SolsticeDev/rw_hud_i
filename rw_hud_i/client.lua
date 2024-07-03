local PlayerData = {}
local isPauseMenu = false

local QBCore = exports['qb-core']:GetCoreObject()

local function updateHUD()
    PlayerData = QBCore.Functions.GetPlayerData()

    if PlayerData and PlayerData.metadata then
        TriggerServerEvent('rw_hud:getServerInfo')

        local hunger = PlayerData.metadata['hunger']
        local thirst = PlayerData.metadata['thirst']

        local status = {
            hunger = hunger,
            thirst = thirst
        }
        SendNUIMessage({ action = 'update', type = 'status', data = { status = status } })
        SendNUIMessage({ action = 'update', type = 'serverId', data = GetPlayerServerId(PlayerId()) })

        -- Postal
        local ped = PlayerPedId()
        local position = GetEntityCoords(ped)
        local streetName = GetStreetNameFromHashKey(GetStreetNameAtCoord(position.x, position.y, position.z))
        local postal = streetName
        SendNUIMessage({ action = 'update', type = 'postal-id', data = postal })
        SendNUIMessage({ action = 'update', type = 'player-count', data = GetNumberOfPlayers() })

        -- Global
        local ped = PlayerPedId()
        local playerId = PlayerId()

        -- Ammo
        if IsPedArmed(ped, 7) then
            SendNUIMessage({ action = 'showElement', type = 'bottom-left-weapon' })
            local weapon = GetSelectedPedWeapon(ped)
            local ammoTotal = GetAmmoInPedWeapon(ped, weapon)
            local bool, ammoClip = GetAmmoInClip(ped, weapon)
            local ammoRemaining = math.floor(ammoTotal - ammoClip)
            SendNUIMessage({ action = 'setWeaponImg', data = weapon })
            SendNUIMessage({ action = 'update', type = 'weapon-info', data = ammoClip .. "/ " .. ammoRemaining })
        else
            SendNUIMessage({ action = 'hideElement', type = 'bottom-left-weapon' })
        end

        -- Health
        SetPlayerHealthRechargeMultiplier(playerId, 0.0)
        local maxHealth = GetEntityMaxHealth(ped) - 100
        local health = GetEntityHealth(ped) - 100
        if health < 0 then health = 0 end
        if lastValues.health ~= health then
            lastValues.health = health
            SendNUIMessage({ action = 'updateBar', type = 'health', current = health, max = maxHealth })
            SendNUIMessage({ action = 'update', type = 'healthbar-value', data = health })
        end

        -- Armor
        local maxArmor = GetPlayerMaxArmour(playerId)
        local armor = GetPedArmour(ped)
        if armor < 0 then armor = 0 end
        if lastValues.armor ~= armor then
            lastValues.armor = armor
            SendNUIMessage({ action = 'updateBar', type = 'vest', current = armor, max = maxArmor })
            SendNUIMessage({ action = 'update', type = 'vestbar-value', data = armor })
        end

        -- Stamina
        local stamina = 100 - GetPlayerSprintStaminaRemaining(playerId)
        if lastValues.stamina ~= stamina then
            lastValues.stamina = stamina
            SendNUIMessage({ action = 'updateBar', type = 'stamina', current = stamina, max = 100 })
        end

        -- Pause Menu
        if IsPauseMenuActive() then
            if not isPauseMenu then
                isPauseMenu = not isPauseMenu
                SendNUIMessage({ action = 'hide' })
            end
        else
            if isPauseMenu then
                isPauseMenu = not isPauseMenu
                SendNUIMessage({ action = 'show' })
            end
        end
    end
end

AddEventHandler('playerSpawned', function()
    updateHUD()
end)

Citizen.CreateThread(function()
    while true do
        Wait(500)
        updateHUD()
    end
end)

-- Overall Info
RegisterNetEvent('rw_hud:setInfo')
AddEventHandler('rw_hud:setInfo', function(info)
    SendNUIMessage({ action = 'update', type = 'society-name', data = PlayerData.job.label or 'ERROR_1' })
    SendNUIMessage({ action = 'update', type = 'money', data = info['money'] or 'ERROR_1' })
    SendNUIMessage({ action = 'update', type = 'bank-account', data = info['bank'] or 'ERROR_1' })
    SendNUIMessage({ action = 'update', type = 'black_money', data = info['blackm'] or 'ERROR_1' })
    SendNUIMessage({ action = 'update', type = 'donate-coins', data = info['dnates'] or 'ERROR_1' })
end)

-- Vehicle
CreateThread(function()
    while true do
        Wait(150)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            SendNUIMessage({ action = 'showElement', type = 'in-vehicle' })
            local vehicle = GetVehiclePedIsIn(ped)
            local data = {
                health = GetVehicleEngineHealth(vehicle),
                speed = GetEntitySpeed(vehicle) * 2.2,
                maxSpeed = GetVehicleMaxSpeed(vehicle) * 2.2,
                fuel = GetVehicleFuelLevel(vehicle),
            }
            SendNUIMessage({ action = 'speedometer', data = data })
        else
            SendNUIMessage({ action = 'hideElement', type = 'in-vehicle' })
        end
    end
end)

-- Stress
local config = Config
local speedMultiplier = config.UseMPH and 2.23694 or 3.6
local stress = 0
local lastStress = 0

RegisterNetEvent('hud:client:UpdateStress', function(newStress) -- Add this event with adding stress elsewhere
    stress = newStress
    SendNUIMessage({
        action = 'updateBar',
        type = 'stress',
        current = newStress,
        max = 100
    })
end)

-- Stress Gain
CreateThread(function() -- Speeding
    while true do
        if LocalPlayer.state.isLoggedIn then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                local vehClass = GetVehicleClass(veh)
                local speed = GetEntitySpeed(veh) * speedMultiplier

                if vehClass ~= 13 and vehClass ~= 14 and vehClass ~= 15 and vehClass ~= 16 and vehClass ~= 21 then
                    local stressSpeed
                    if vehClass == 8 then
                        stressSpeed = config.MinimumSpeed
                    else
                        stressSpeed = seatbeltOn and config.MinimumSpeed or config.MinimumSpeedUnbuckled
                    end
                    if speed >= stressSpeed then
                        TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
                    end
                end
            end
        end
        Wait(10000)
    end
end)

local function IsWhitelistedWeaponStress(weapon)
    if weapon then
        for _, v in pairs(config.WhitelistedWeaponStress) do
            if weapon == v then
                return true
            end
        end
    end
    return false
end

CreateThread(function() -- Shooting
    while true do
        if LocalPlayer.state.isLoggedIn then
            local ped = PlayerPedId()
            local weapon = GetSelectedPedWeapon(ped)
            if weapon ~= `WEAPON_UNARMED` then
                if IsPedShooting(ped) and not IsWhitelistedWeaponStress(weapon) then
                    if math.random() < config.StressChance then
                        TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
                    end
                end
            else
                Wait(1000)
            end
        end
        Wait(8)
    end
end)

-- Stress Screen Effects
local function GetBlurIntensity(stresslevel)
    for _, v in pairs(config.Intensity['blur']) do
        if stresslevel >= v.min and stresslevel <= v.max then
            return v.intensity
        end
    end
    return 1500
end

local function GetEffectInterval(stresslevel)
    for _, v in pairs(config.EffectInterval) do
        if stresslevel >= v.min and stresslevel <= v.max then
            return v.timeout
        end
    end
    return 60000
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local effectInterval = GetEffectInterval(stress)
        if stress >= 100 then
            local BlurIntensity = GetBlurIntensity(stress)
            local FallRepeat = math.random(2, 4)
            local RagdollTimeout = FallRepeat * 1750
            TriggerScreenblurFadeIn(1000.0)
            Wait(BlurIntensity)
            TriggerScreenblurFadeOut(1000.0)

            if not IsPedRagdoll(ped) and IsPedOnFoot(ped) and not IsPedSwimming(ped) then
                SetPedToRagdollWithFall(ped, RagdollTimeout, RagdollTimeout, 1, GetEntityForwardVector(ped), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
            end

            Wait(1000)
            for _ = 1, FallRepeat, 1 do
                Wait(750)
                DoScreenFadeOut(200)
                Wait(1000)
                DoScreenFadeIn(200)
                TriggerScreenblurFadeIn(1000.0)
                Wait(BlurIntensity)
                TriggerScreenblurFadeOut(1000.0)
            end
        elseif stress >= config.MinimumStress then
            local BlurIntensity = GetBlurIntensity(stress)
            TriggerScreenblurFadeIn(1000.0)
            Wait(BlurIntensity)
            TriggerScreenblurFadeOut(1000.0)
        end
        Wait(effectInterval)
    end
end)

CreateThread(function() -- Update stress bar
    while true do
        if stress ~= lastStress then
            SendNUIMessage({
                action = 'updateBar',
                type = 'stress',
                current = stress,
                max = 100
            })
            lastStress = stress
        end
        Wait(500) -- Check every half second
    end
end)
