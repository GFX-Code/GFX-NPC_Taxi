Config = {}

Config = {
    price_per_landing = 25, -- base price for when the player starts a journey
    price_per_second = 1,  
    vehicle_model = "taxi",
    driver_model = "a_m_m_eastsa_02"
}

Config.TaxiCallFee = 50       -- minimum required to even call taxi

Config.SpeedLimitZones = {
    [2]  = 40, -- normal roads (city & regular streets)
    [64] = 25, -- off-road (dirt, sand, trails)
    [66] = 60, -- highways / freeways
}

Config.DrivingStyles = {
    normal = {
        style = 786607,
        speedMult = 1.0,
        aggressiveness = 0.5,
    },
    rush = {
        style = 787263,
        speedMult = 2.0,
        aggressiveness = 1.0,
    },
}

Config.PayphoneModels = { -- add more models if needed
    `prop_phonebox_04`,
    `prop_phonebox_03`,
}

Config.PlacedPayphones = { -- example placed payphones, you can add your own
    { coords = vec4(-1896.5, 685.66, 127.46, 46.75), prop = `prop_phonebox_03` },
}

Config.Framework = {}

function Config.Framework.ESX()
    return GetResourceState("es_extended") ~= "missing"
end

function Config.Framework.QBCore()
    return GetResourceState("qb-core") ~= "missing"
end

function Config.Framework.QBBox()
    return GetResourceState("qbx_core") ~= "missing"
end