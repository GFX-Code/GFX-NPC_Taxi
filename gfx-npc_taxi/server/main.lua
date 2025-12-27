RegisterNetEvent('taxi:callFromPayphone')
AddEventHandler('taxi:callFromPayphone', function()
    local src = source
    if src > 0 then
        TriggerClientEvent('taxi:client:callVehicle', src)
    end
end)

lib.callback.register('taxi:server:canAffordTaxi', function(source)
    local src = source

    if not Config.Framework.QBBox() then return false end

    local player = exports['qbx_core']:GetPlayer(src)
    if not player then return false end

    local cash = player.PlayerData.money.cash or 0
    local bank = player.PlayerData.money.bank or 0

    return (cash + bank) >= Config.TaxiCallFee
end)

lib.callback.register('taxi:server:payForTaxi', function(source, price)
    local src = source

    if not Config.Framework.QBBox() then return false end

    local player = exports['qbx_core']:GetPlayer(src)
    if not player then return false end

    price = tonumber(price)
    if not price or price <= 0 then return true end

    if player.Functions.RemoveMoney('cash', price, 'taxi') then
        return true
    end

    if player.Functions.RemoveMoney('bank', price, 'taxi') then
        return true
    end

    lib.notify(src, {
        type = 'warning',
        description = 'Not enough money!',
        position = 'center-right',
        duration = 5000
    })

    return false
end)

AddEventHandler("onResourceStop", function(resName)
    if resName == GetCurrentResourceName() then
        print("[taxi] Server resource stopped, no cleanup needed.")
    end
end)
