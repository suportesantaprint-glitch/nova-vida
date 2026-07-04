flashlightEnabled = false

if not DrawFlashlight then
    function DrawFlashlight(ped)
        local boneCoords = GetPedBoneCoords(ped, 28422, 0.5, 0.0, 0.0)
        local forwardVector = GetEntityForwardVector(ped)
        
        DrawSpotLightWithShadow(
            boneCoords.x, boneCoords.y, boneCoords.z,
            forwardVector.x, forwardVector.y, forwardVector.z,
            255, 255, 255, 15.0, 3.0, 0.0, 50.0, 100.0, 1
        )
        
        DrawSpotLightWithShadow(
            boneCoords.x, boneCoords.y, boneCoords.z,
            forwardVector.x, forwardVector.y, forwardVector.z,
            255, 255, 255, 30.0, 10.0, 0.0, 20.0, 25.0, 1
        )
    end
end

local function toggleFlashlight(enabled)
    local wasEnabled = flashlightEnabled
    flashlightEnabled = enabled == true
    
    if flashlightEnabled == wasEnabled then
        return
    end
    
    TriggerServerEvent("phone:toggleFlashlight", flashlightEnabled)
    
    if not flashlightEnabled then
        return
    end
    
    Citizen.CreateThreadNow(function()
        local playerPed = PlayerPedId()
        
        while flashlightEnabled do
            if phoneOpen then
                DrawFlashlight(playerPed)
            else
                Wait(500)
            end
            Wait(0)
        end
    end)
end

RegisterNUICallback("toggleFlashlight", function(data, callback)
    toggleFlashlight(data.toggled)
    
    SetTimeout(100, function()
        callback(flashlightEnabled)
    end)
end)

exports("ToggleFlashlight", function(enabled)
    if not phoneOpen then
        return
    end
    
    toggleFlashlight(enabled)
    SendReactMessage("toggleFlashlight", flashlightEnabled)
end)

exports("GetFlashlight", function()
    return flashlightEnabled == true
end)

if not Config.SyncFlash then
    return
end

local nearbyFlashlights = {}
local drawingFlashlights = false

local function startDrawingFlashlights()
    if drawingFlashlights then
        return
    end
    
    drawingFlashlights = true
    
    Citizen.CreateThreadNow(function()
        debugprint("Started drawing flashlights")
        
        while drawingFlashlights do
            for i = 1, #nearbyFlashlights do
                DrawFlashlight(nearbyFlashlights[i])
            end
            Wait(0)
        end
        
        debugprint("Stopped drawing flashlights")
    end)
end

AddStateBagChangeHandler("flashlight", nil, function(bagName, key, value, reserved, replicated)
    local playerId = GetPlayerFromStateBagName(bagName)
    
    if not playerId or playerId == 0 or playerId == PlayerId() then
        return
    end
    
    local playerPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local targetCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - targetCoords)
    
    if distance > 30.0 then
        return
    end
    
    local pedIndex = table.contains(nearbyFlashlights, playerPed)
    
    if not pedIndex and value then
        nearbyFlashlights[#nearbyFlashlights + 1] = playerPed
    elseif pedIndex and not value then
        table.remove(nearbyFlashlights, pedIndex)
    end
    
    if #nearbyFlashlights > 0 then
        startDrawingFlashlights()
    else
        drawingFlashlights = false
    end
end)

CreateThread(function()
    while true do
        if #nearbyFlashlights > 0 then
            table.wipe(nearbyFlashlights)
        end
        
        local playerCoords = GetEntityCoords(PlayerPedId())
        local nearbyPlayers = GetNearbyPlayers()
        
        for i = 1, #nearbyPlayers do
            local player = nearbyPlayers[i]
            local playerState = Player(player.source).state
            
            if playerState.flashlight and playerState.phoneOpen then
                local distance = #(playerCoords - GetEntityCoords(player.ped))
                
                if distance <= 30.0 then
                    nearbyFlashlights[#nearbyFlashlights + 1] = player.ped
                end
            end
        end
        
        if #nearbyFlashlights > 0 then
            startDrawingFlashlights()
        else
            drawingFlashlights = false
        end
        
        Wait(1000)
    end
end)