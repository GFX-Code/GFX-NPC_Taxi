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
    else
        if taxiInstance.state == "idle" then
            taxiInstance:Cleanup()
            Citizen.Wait(500)
            taxiInstance:RequestTaxi(playerCoords)
        else
            lib.notify({
                type = 'warning',
                description = 'A taxi is already on the way!',
                duration = 5000
            })
        end
    end
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
        lib.notify({type = "success", description = "Taxi is now driving faster!"})
    end
end, false)

RegisterKeyMapping("taxiRushMode", "Speed up the taxi", "keyboard", "E")

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        if taxiInstance
            and taxiInstance.state == "in_trip"
            and taxiInstance.driver
            and DoesEntityExist(taxiInstance.driver)
            and IsPedInVehicle(playerPed, taxiInstance.vehicle, false)
            and not taxiInstance.rushMode
        then
            lib.showTextUI("[E] Press to speed up")
        else
            lib.hideTextUI()
        end
    end
end)

AddEventHandler("onResourceStop", function(resName)
    if resName == GetCurrentResourceName() and taxi then
        taxi:Cleanup()
    end
end)

Citizen.CreateThread(function()
    local payphoneModels = Config.PayphoneModels or {}
    for _, model in ipairs(payphoneModels) do
        if type(model) == "number" or type(model) == "string" then
            exports.ox_target:addModel({model}, {
                {
                    name = 'call_taxi',
                    icon = 'fa-solid fa-car',
                    label = 'Call Taxi',
                    distance = 2.5,
                    onSelect = function()
                        TriggerServerEvent('taxi:callFromPayphone')
                    end
                }
            })
        end
    end
end)
