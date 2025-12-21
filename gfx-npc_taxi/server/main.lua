RegisterNetEvent('taxi:callFromPayphone')
AddEventHandler('taxi:callFromPayphone', function()
    local src = source
    if src > 0 then
        TriggerClientEvent('taxi-bot:client:callVehicle', src)
    end
end)

lib.callback.register('taxi:server:payForTaxi', function(source, price)
    local src = source
    if Config.Framework.QBBox() then
        local player = exports['qbx_core']:GetPlayer(src)
        if player and player.PlayerData then
            local paid = false
            if player.Functions.RemoveMoney('cash', price, GetCurrentResourceName()) then
                paid = true
            elseif player.Functions.RemoveMoney('bank', price, GetCurrentResourceName()) then
                paid = true
            end

            if paid then
                return true
            else
                TriggerClientEvent('ox_lib:notify', src, {
                    type = 'warning',
                    description = 'Not enough money!',
                    position = "center-right",
                    duration = 5000
                })
                return false
            end
        end
    end
end)

AddEventHandler("onResourceStop", function(resName)
    if resName == GetCurrentResourceName() then
        print("[taxi] Server resource stopped, no cleanup needed.")
    end
end)
