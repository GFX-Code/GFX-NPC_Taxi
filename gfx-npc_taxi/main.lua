local function CallTaxi()
    TriggerServerEvent('taxi:callFromPayphone')
end

local taxiClass = require 'client.classes.taxi'
local taxiInstance = nil

RegisterNetEvent('taxi-bot:client:callVehicle', function()
    local playerCoords = GetEntityCoords(PlayerPedId())

    if not taxiInstance then
        taxiInstance = taxiClass:new()
        taxiInstance:RequestTaxi(playerCoords)
        return
    end

    if taxiInstance.state == "idle" then
        taxiInstance:Cleanup()
        Wait(500)
        taxiInstance:RequestTaxi(playerCoords)
        return
    end

    lib.notify({
        type = 'warning',
        description = 'A taxi is already on the way!',
        duration = 5000
    })
end)

RegisterCommand("taxiRushMode", function()
    local playerPed = PlayerPedId()

    if taxiInstance
        and taxiInstance.state == "in_trip"
        and taxiInstance.driver
        and DoesEntityExist(taxiInstance.driver)
        and IsPedInVehicle(playerPed, taxiInstance.vehicle, false)
        and not taxiInstance.rushMode
    then
        taxiInstance.rushMode = true
        lib.notify({
            type = "success",
            description = "Taxi is now driving faster!"
        })
    end
end, false)

RegisterKeyMapping("taxiRushMode", "Speed up the taxi", "keyboard", "E")

CreateThread(function()
    local uiShown = false

    while true do
        Wait(1000) -- checks every 1000ms instead of every frame, thank you Randolio

        local playerPed = PlayerPedId()
        local shouldShow = taxiInstance
            and taxiInstance.state == "in_trip"
            and taxiInstance.driver
            and DoesEntityExist(taxiInstance.driver)
            and IsPedInVehicle(playerPed, taxiInstance.vehicle, false)
            and not taxiInstance.rushMode

        if shouldShow and not uiShown then
            lib.showTextUI("[E] Press to speed up")
            uiShown = true
        elseif not shouldShow and uiShown then
            lib.hideTextUI()
            uiShown = false
        end
    end
end)

local spawnedPayphones = {} 

CreateThread(function()
    if not Config.PlacedPayphones then return end

    for _, phone in pairs(Config.PlacedPayphones) do
        RequestModel(phone.prop)
        while not HasModelLoaded(phone.prop) do
            Wait(0)
        end

        local obj = CreateObject(
            phone.prop,
            phone.coords.x,
            phone.coords.y,
            phone.coords.z - 1.0,
            false,
            false,
            false
        )

        SetEntityHeading(obj, phone.coords.w)
        FreezeEntityPosition(obj, true)
        SetEntityInvincible(obj, true)

        spawnedPayphones[obj] = true

        exports.ox_target:addLocalEntity(obj, {
            {
                name = 'call_taxi_custom_phone',
                icon = 'fa-solid fa-car',
                label = 'Call Taxi',
                distance = 2.5,
                onSelect = CallTaxi
            }
        })

        SetModelAsNoLongerNeeded(phone.prop)
    end
end)

local worldPayphones = {}

CreateThread(function()
    local models = Config.PayphoneModels or {}

    while true do
        Wait(2000)

        local playerCoords = GetEntityCoords(PlayerPedId())

        for _, model in ipairs(models) do
            local phone = GetClosestObjectOfType(
                playerCoords.x,
                playerCoords.y,
                playerCoords.z,
                3.0,
                model,
                false,
                false,
                false
            )

            if phone ~= 0
                and not worldPayphones[phone]
                and not spawnedPayphones[phone]
            then
                worldPayphones[phone] = true

                exports.ox_target:addLocalEntity(phone, {
                    {
                        name = 'call_taxi_world_phone',
                        icon = 'fa-solid fa-car',
                        label = 'Call Taxi',
                        distance = 2.5,
                        onSelect = CallTaxi
                    }
                })
            end
        end
    end
end)

AddEventHandler("onResourceStop", function(resName)
    if resName ~= GetCurrentResourceName() then return end

    for obj,_ in pairs(spawnedPayphones) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end

    if taxiInstance then
        taxiInstance:Cleanup()
    end
end)
