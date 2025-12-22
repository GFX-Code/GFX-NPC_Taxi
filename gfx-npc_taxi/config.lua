Config = {}

Config = {
    price_per_landing = 25, -- base price for when the player starts a journey
    price_per_second = 1,  
    vehicle_model = "taxi",
    driver_model = "a_m_m_eastsa_02"
}

Config.SpeedLimitZones = {
    [2]  = 40, -- Normal roads (city & regular streets)
    [64] = 25, -- Off-road (dirt, sand, trails)
    [66] = 60, -- Highways / freeways
}

Config.DrivingStyles = {
    normal = {
        style = 786607,
        speedMult = 1.0,
        aggressiveness = 0.5,
    },
    rush = {
        style = 787263,
        speedMult = 1.5,
        aggressiveness = 0.75,
    },
}

Config.PayphoneModels = {
    `prop_phonebox_04`,
    `prop_phonebox_03`,
}

Config.PlacedPayphones = {
    { coords = vec4(-267.46, -767.04, 32.45, 90.41), prop = `prop_phonebox_04` },
    { coords = vec4(-266.06, -763.78, 32.52, 70.24), prop = `prop_phonebox_03` },
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