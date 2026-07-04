local isTrackingCoords = false
local playerPed = PlayerPedId()
local lastCoords = vector3(0, 0, 0)

local function addLocationToSaved(locationName, coordinates)
    if not locationName then
        return false
    end
    
    local coords
    if coordinates then
        coords = vector2(coordinates[2], coordinates[1])
    else
        local playerCoords = GetEntityCoords(PlayerPedId())
        coords = playerCoords
    end
    
    local locationId = AwaitCallback("maps:addLocation", locationName, coords.x, coords.y)
    if not locationId then
        return false
    end
    
    local newLocation = {
        id = locationId,
        name = locationName,
        position = {coords.y, coords.x}
    }
    
    table.insert(SavedLocations, newLocation)
    return newLocation
end

local function startCoordinateTracking()
    playerPed = PlayerPedId()
    lastCoords = GetEntityCoords(playerPed)
    
    SendReactMessage("maps:updateCoords", {
        x = math.floor(lastCoords.x + 0.5),
        y = math.floor(lastCoords.y + 0.5)
    })
    
    while isTrackingCoords do
        local currentCoords = GetEntityCoords(playerPed)
        
        if phoneOpen then
            local distance = #(lastCoords - currentCoords)
            if distance > 1.0 then
                lastCoords = currentCoords
                SendReactMessage("maps:updateCoords", {
                    x = math.floor(currentCoords.x + 0.5),
                    y = math.floor(currentCoords.y + 0.5)
                })
            end
        end
        
        Wait(250)
    end
end

RegisterNUICallback("Maps", function(data, callback)
    local action = data.action
    debugprint("Maps:" .. (action or ""))
    
    if action == "getCurrentLocation" then
        local coords = GetEntityCoords(PlayerPedId())
        callback({x = coords.x, y = coords.y})
    elseif action == "toggleUpdateCoords" then
        callback("ok")
        
        if isTrackingCoords == data.toggle then
            return
        end
        
        isTrackingCoords = data.toggle
        startCoordinateTracking()
    elseif action == "setWaypoint" then
        callback("ok")
        
        local waypointData = data.data
        local x = tonumber(waypointData.x)
        local y = tonumber(waypointData.y)
        
        if x and y then
            SetNewWaypoint(x, y)
        end
    elseif action == "getLocations" then
        callback(SavedLocations)
    elseif action == "addLocation" then
        callback(addLocationToSaved(data.name, data.location))
    elseif action == "renameLocation" then
        local newName = data.name
        local success = false
        
        if newName then
            success = AwaitCallback("maps:renameLocation", data.id, newName)
        end
        
        if not success then
            return callback(false)
        end
        
        for i = 1, #SavedLocations do
            if SavedLocations[i].id == data.id then
                SavedLocations[i].name = newName
                break
            end
        end
        
        callback(true)
    elseif action == "removeLocation" then
        local success = AwaitCallback("maps:removeLocation", data.id)
        if not success then
            return callback(false)
        end
        
        for i = 1, #SavedLocations do
            if SavedLocations[i].id == data.id then
                table.remove(SavedLocations, i)
                break
            end
        end
        
        callback(true)
    end
end)