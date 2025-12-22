local taxi = {}
taxi.__index = taxi

function taxi:new()
    local obj = setmetatable({}, self)
    obj.model = Config.vehicle_model or "taxi"
    obj.driverModel = Config.driver_model or "a_m_m_eastsa_02"
    obj.state = "idle"
    obj.attempts = 0
    obj.maxAttempts = 3
    obj.plate = nil
    obj.price = 0
    obj.rushMode = false
    obj.vehicle = nil
    obj.driver = nil
    obj.blip = nil
    return obj
end

function taxi:RequestTaxi(playerCoords)
    if self.state ~= "idle" then
        lib.notify({type = 'error', description = 'A taxi has already been requested'})
        return false
    end

    self.state = "spawning"
    self.playerCoords = playerCoords or GetEntityCoords(PlayerPedId())
    self.attempts = 0

    self:FindSpawnPositionAndSpawn()
    return true
end

function taxi:FindNearestRoadNode(coords, maxDistance)
    maxDistance = maxDistance or 50.0
    local roadCoords = coords
    local found = false
    local nodeType = 1
    local success, nodePos, nodeHeading

    success, nodePos = GetNthClosestVehicleNode(coords.x, coords.y, coords.z, 0, nodeType, 0, 0)
    if success and nodePos then
        if #(coords - nodePos) <= maxDistance then
            roadCoords = vector4(nodePos.x, nodePos.y, nodePos.z, GetEntityHeading(PlayerPedId()))
            found = true
        end
    end

    if not found then
        success, nodePos, nodeHeading = GetClosestVehicleNodeWithHeading(coords.x, coords.y, coords.z, nodeType, 0, 0)
        if success and nodePos then
            if #(coords - nodePos) <= maxDistance then
                roadCoords = vector4(nodePos.x, nodePos.y, nodePos.z, nodeHeading)
                found = true
            end
        end
    end

    if not found then
        success, nodePos, nodeHeading = GetRoadSidePointWithHeading(coords.x, coords.y, coords.z, 0)
        if success and nodePos then
            if #(coords - nodePos) <= maxDistance then
                roadCoords = vector4(nodePos.x, nodePos.y, nodePos.z, nodeHeading)
                found = true
            end
        end
    end

    if not found then
        local groundFound, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
        if groundFound then
            roadCoords = vector4(coords.x, coords.y, groundZ + 0.5, GetEntityHeading(PlayerPedId()) or 0.0)
        else
            roadCoords = vector4(coords.x, coords.y, coords.z, GetEntityHeading(PlayerPedId()) or 0.0)
        end
    end

    return roadCoords
end

function taxi:FindSpawnPositionAndSpawn()
    local found = false
    local spawnCoords = nil
    while not found and self.attempts < self.maxAttempts do
        self.attempts = self.attempts + 1
        local randomAngle = math.random() * math.pi * 2
        local randomDistance = math.random(150, 200)
        local randomOffset = vector3(math.cos(randomAngle) * randomDistance, math.sin(randomAngle) * randomDistance, 0)
        local potentialCoords = self.playerCoords + randomOffset
        spawnCoords = self:FindNearestRoadNode(potentialCoords, 50.0)
        if self:IsPathValid(spawnCoords, self.playerCoords) then
            found = true
            break
        end
        Citizen.Wait(0)
    end

    if found and spawnCoords then
        self:SpawnTaxi(spawnCoords)
    else
        lib.notify({type = 'error', description = 'The driver could not find a suitable route to get to you'})
        self.state = "idle"
    end
end

function taxi:IsPathValid(startCoords, endCoords)
    local success = CalculateTravelDistanceBetweenPoints(
        startCoords.x, startCoords.y, startCoords.z,
        endCoords.x, endCoords.y, endCoords.z,
        0.0, 0
    )
    return success > 0 and success < 1000.0
end

function taxi:SpawnTaxi(spawnCoords)
    local modelHash = joaat(self.model)
    if not lib.requestModel(modelHash, 5000) then
        lib.notify({type = 'error', description = 'Taxi model loading error'})
        self.state = "idle"
        return
    end

    local vehicle = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z + 0.5, spawnCoords.w or 0.0, true, false)
    if not DoesEntityExist(vehicle) then
        lib.notify({type = 'error', description = 'Taxi creation error'})
        self.state = "idle"
        return
    end

    self.vehicle = vehicle
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleColours(vehicle, 0, 88)
    self.plate = "TAXI " .. math.random(100, 999)
    SetVehicleNumberPlateText(vehicle, self.plate)
    SetVehicleRadioEnabled(vehicle, false)
    if exports['cdn-fuel'] and exports['cdn-fuel'].SetFuel then
        exports['cdn-fuel']:SetFuel(vehicle, 100)
    elseif SetVehicleFuelLevel then
        SetVehicleFuelLevel(vehicle, 100.0)
    end

    self:CreateDriver()
    SetVehicleEngineOn(vehicle, true, true, false)
    self:SetupBlip()

    lib.notify({
        type = 'success',
        description = 'Taxi with the license plate '..self.plate..' is on its way! Please wait for it to arrive.',
        duration = 5000
    })

    self.state = "driving"
    self:DriveToPlayer()
end

function taxi:CreateDriver()
    local driverHash = joaat(self.driverModel)
    if not lib.requestModel(driverHash, 3000) then return end
    local driver = CreatePedInsideVehicle(self.vehicle, 4, driverHash, -1, true, false)
    if driver and DoesEntityExist(driver) then
        self.driver = driver
        SetEntityAsMissionEntity(driver, true, true)
        SetBlockingOfNonTemporaryEvents(driver, true)
        SetPedFleeAttributes(driver, 0, false)
        SetPedKeepTask(driver, true)
        SetDriverAbility(driver, 1.0)
        SetDriverAggressiveness(driver, 0.1)
        SetAmbientVoiceName(driver, 'A_M_M_RUSSIAN_01')
    end
end

function taxi:SetupBlip()
    if self.blip then RemoveBlip(self.blip) end
    self.blip = AddBlipForEntity(self.vehicle)
    SetBlipSprite(self.blip, 198)
    SetBlipColour(self.blip, 5)
    SetBlipScale(self.blip, 0.8)
    SetBlipDisplay(self.blip, 4)
    SetBlipCategory(self.blip, 0)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Taxi")
    EndTextCommandSetBlipName(self.blip)
end

function taxi:DriveToPlayer()
    if not self.driver or not DoesEntityExist(self.driver) then self:Cleanup() return end
    local target = getStoppingLocation(GetEntityCoords(PlayerPedId()))
    TaskVehicleDriveToCoord(self.driver, self.vehicle, target.x, target.y, target.z, 10.0, 0, GetEntityModel(self.vehicle), Config.DrivingStyles.normal.style, 5.0, true)

    Citizen.CreateThread(function()
        while self.state == "driving" do
            Citizen.Wait(500)
            if not self:IsValid() then self:Cleanup() return end
            local distance = #(GetEntityCoords(self.vehicle) - target)
            if distance <= 16.0 then
                self.state = "arrived"
                self:OnArrival()
                break
            end
        end
    end)
end

function taxi:DriveTo(x, y, z)
    if not self.driver or not DoesEntityExist(self.driver) then self:Cleanup() return end
    local target = getStoppingLocation(vec3(x, y, z))
    SetVehicleDoorsLocked(self.vehicle, 4)
    self.state = "in_trip"
    self.price = Config.price_per_landing

    Citizen.CreateThread(function()
        while self.state == "in_trip" do
            Citizen.Wait(5000)
            self.price = (self.price or 0) + Config.price_per_second
        end
    end)

    Citizen.CreateThread(function()
        while self.state == "in_trip" do
            Citizen.Wait(500)
            if not self:IsValid() then self:Cleanup() return end

            local taxiCoords = GetEntityCoords(self.vehicle)
            local distance = #(taxiCoords - target)
            local speed = self.rushMode and 50.0 or 20.0
            local style = self.rushMode and Config.DrivingStyles.rush.style or Config.DrivingStyles.normal.style

            if distance > 16.0 then
                TaskVehicleDriveToCoordLongrange(self.driver, self.vehicle, target.x, target.y, target.z, speed, style, 1.0)
                SetPedKeepTask(self.driver, true)
            else
                ClearPedTasks(self.driver)
                self.state = "trip_complete"
                self:OnArrival()
                break
            end
        end
    end)
end

taxi = taxi or nil

function Draw2DText(text, x, y, scale, color)
    SetTextFont(11)
    SetTextProportional(1)
    SetTextScale(scale, scale)
    SetTextColour(color[1], color[2], color[3], color[4] or 255)
    SetTextDropShadow(0, 0, 0, 0, 0)
    SetTextEdge(0, 0, 0, 0, 0)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

function taxi:MonitorTrip()
    Citizen.CreateThread(function()
        while self.state == "in_trip" do
            if IsControlJustReleased(0, 177) then
                self:Cancel()
                break
            end
            Draw2DText(string.format("Total cost: $%s", self.price), 0.085, 0.727, 0.27, {255, 255, 0, 255})
            Citizen.Wait(0)
        end
    end)
end

--[[Debug command to display a test trip cost - i used this for positioning with the minimap
RegisterCommand("showTripCost", function()
    local display = true
    local testPrice = 123.45

    Citizen.CreateThread(function()
        while display do
            Citizen.Wait(0)
            Draw2DText(string.format("Total cost: $%s", testPrice), 0.08, 0.727, 0.27, {255, 255, 0, 255})

            if IsControlJustReleased(0, 177) then
                display = false
            end
        end
    end)
end, false)]]

function taxi:OnArrival()
    TaskVehicleTempAction(self.driver, self.vehicle, 6, 5000)
    SetVehicleEngineOn(self.vehicle, true, true, false)

    if self.state == "arrived" then
        lib.notify({type='success', description='Your taxi has arrived! Approach the car and get in the back seat', duration=7000})
        StartVehicleHorn(self.vehicle, 500, 0, true)
        self:StartWaitingTimer()
    elseif self.state == "trip_complete" then
        SetVehicleDoorsLocked(self.vehicle, 1)
        playTaxiSpeech(self.driver, "TAXID_ARRIVE_AT_DEST", "SPEECH_PARAMS_FORCE_NORMAL")
        Wait(1500)
        lib.notify({type='success', description='Journey complete, thank you for riding with us', duration=7000})
        TaskLeaveVehicle(PlayerPedId(), self.vehicle, 1)
        Wait(1500)
        self:Pay()
        StartVehicleHorn(self.vehicle, 1500, 0, true)
        ClearPedTasks(self.driver)
        SetEntityAsNoLongerNeeded(self.driver)
        SetEntityAsNoLongerNeeded(self.vehicle)
        Wait(15000)
        self:Cleanup()
    end
end

function taxi:FlashLights()
    for i = 1, 2 do
        SetVehicleLights(self.vehicle, 2)
        Citizen.Wait(300)
        SetVehicleLights(self.vehicle, 0)
        Citizen.Wait(300)
    end
    SetVehicleLights(self.vehicle, 1) 
end

function taxi:SeatToVehicle()
    local playerPed = PlayerPedId()

    if IsPedInVehicle(playerPed, self.vehicle, false) then
        return true
    end

    local seatIndex = 1
    if IsVehicleSeatFree(self.vehicle, seatIndex) then
        SetVehicleDoorsLocked(self.vehicle, 1)
        TaskEnterVehicle(playerPed, self.vehicle, 5000, seatIndex, 1.0, 1, 0)

        local timeout = 0
        while not IsPedInVehicle(playerPed, self.vehicle, false) and timeout < 50 do
            Citizen.Wait(100)
            timeout = timeout + 1
        end

        return IsPedInVehicle(playerPed, self.vehicle, false)
    end

    for i = 2, GetVehicleModelNumberOfSeats(GetEntityModel(self.vehicle)) - 1 do
        if IsVehicleSeatFree(self.vehicle, i) then
            SetVehicleDoorsLocked(self.vehicle, 1)
            TaskEnterVehicle(playerPed, self.vehicle, 5000, i, 1.0, 1, 0)

            local timeout = 0
            while not IsPedInVehicle(playerPed, self.vehicle, false) and timeout < 50 do
                Citizen.Wait(100)
                timeout = timeout + 1
            end

            return IsPedInVehicle(playerPed, self.vehicle, false)
        end
    end

    return false
end

function taxi:StartWaitingTimer()
    local waitTime = 120 
    local startTime = GetGameTimer()

    while self.state == "arrived" do
        Citizen.Wait(1000)

        if (GetVehiclePedIsTryingToEnter(PlayerPedId()) == self.vehicle) then
            if not self:SeatToVehicle() then
                return
            end
        end
        if IsPedInVehicle(PlayerPedId(), self.vehicle, false) then
            self:StartTrip()
            return
        end

        if GetGameTimer() - startTime > waitTime * 1000 then
            lib.notify({type = 'info', description = 'The taxi left due to waiting too long'})
            self:Cleanup()
            return
        end

        local remaining = waitTime - math.floor((GetGameTimer() - startTime) / 1000)
        if remaining % 30 == 0 then
            StartVehicleHorn(self.vehicle, 1000, 0, true)
            lib.notify({
                type = 'info',
                description = 'The taxi is waiting for you! Time left: ' .. remaining .. ' sec',
                duration = 5000
            })
        end
    end
end

function taxi:Pay()

    lib.callback("taxi:server:payForTaxi", false, function(data)
        if not data then
        end
    end, self.price)
end

local function GetWaypointCoords()
    local blip = GetFirstBlipInfoId(8) 
    if blip ~= 0 then
        local x, y, z = table.unpack(GetBlipInfoIdCoord(blip))
        return vector3(x, y, z)
    end
    return nil
end

function taxi:StartTrip()
    self.state = "in_trip"

    playTaxiSpeech(self.driver, "TAXID_BEGIN_JOURNEY", "SPEECH_PARAMS_FORCE_NORMAL")
    lib.notify({
        type = 'inform',
        description = 'To start the trip, tell the driver where to go',
        duration = 5000
    })

    local waypoint = GetWaypointCoords()
    if waypoint then
        local tx, ty, tz = waypoint.x, waypoint.y, waypoint.z
        self.state = "in_trip"
        lib.notify({
            type = 'success',
            description = 'Trip started! Press Backspace to cancel',
            duration = 5000
        })
        self:DriveTo(tx, ty, tz)
        self:MonitorTrip()
    else
        lib.notify({type='error', description='No destination has been set!'})
    end
end

function taxi:HandleStuck()
    print("[taxi] Taxi is stuck, trying to solve the problem...")

    TaskVehicleTempAction(self.driver, self.vehicle, 32, 2000)
    Citizen.Wait(2500)

    local currentCoords = GetEntityCoords(self.vehicle)
    if GetEntitySpeed(self.vehicle) * 3.6 < 2.0 then
    self:DriveToPlayer() 
    end
end

function taxi:IsValid()
    return self.vehicle and DoesEntityExist(self.vehicle) and
            self.driver and DoesEntityExist(self.driver)
end

function taxi:Cleanup()
    if self.vehicle and DoesEntityExist(self.vehicle) then
        DeleteEntity(self.vehicle)
    end
    if self.driver and DoesEntityExist(self.driver) then
        DeleteEntity(self.driver)
    end
    if self.blip then
        RemoveBlip(self.blip)
    end
    SetVehicleDoorsLocked(self.vehicle, 1)
    self.state = "idle"
    self.vehicle = nil
    self.driver = nil
    self.blip = nil
    self.price = 0
end

function taxi:Cancel()
    if self.state ~= "idle" then
        lib.notify({type = 'info', description = 'Taxi ride has been cancelled'})
        self:Pay()
        if IsPedInVehicle(PlayerPedId(), self.vehicle, false) then
            TaskLeaveVehicle(PlayerPedId(), self.vehicle, 1)
            local timeout = 0
            while IsPedInVehicle(PlayerPedId(), self.vehicle, false) and timeout < 50 do
                Citizen.Wait(100)
                timeout = timeout + 1
            end
        end
        if self.driver and DoesEntityExist(self.driver) then
            local taxiCoords = GetEntityCoords(self.vehicle)
            local playerCoords = GetEntityCoords(PlayerPedId())
            local angle = math.random() * math.pi * 2
            local awayDistance = math.random(300, 500)
            local offset = vector3(math.cos(angle) * awayDistance, math.sin(angle) * awayDistance, 0)
            local driveAwayCoords = taxiCoords + offset
            if #(driveAwayCoords - playerCoords) < 200.0 then
                driveAwayCoords = taxiCoords + offset * 2
            end
            TaskVehicleDriveToCoord(self.driver, self.vehicle, driveAwayCoords.x, driveAwayCoords.y, driveAwayCoords.z, 30.0, 0, GetEntityModel(self.vehicle), 786603, 10.0, true)
            SetPedKeepTask(self.driver, true)
            Wait(7000)
        end
        self:Cleanup()
    end
end

return taxi