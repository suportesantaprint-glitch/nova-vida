if not Config.Voice.RecordNearby then
    return
end

local nearbyVoices = {}

local function updateNearbyVoices()
    local newVoices = {}
    local nearbyPlayers = GetNearbyPlayers()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for i = 1, #nearbyPlayers do
        local player = nearbyPlayers[i]
        local playerState = Player(player.source).state
        local listeningChannel = playerState and playerState.listeningPeerId
        
        if listeningChannel then
            local distance = #(playerCoords - GetEntityCoords(player.ped))
            
            if distance <= 25.0 then
                newVoices[#newVoices + 1] = {
                    source = player.source,
                    ped = player.ped,
                    channel = listeningChannel
                }
                
                local existingVoice = nil
                for j = 1, #nearbyVoices do
                    if nearbyVoices[j].source == player.source then
                        existingVoice = nearbyVoices[j]
                        newVoices[#newVoices].volume = existingVoice.volume
                        break
                    end
                end
                
                if not existingVoice then
                    local volume = GetVoiceVolume(distance)
                    newVoices[#newVoices].volume = volume
                    
                    SendReactMessage("voice:joinChannel", {
                        channel = listeningChannel,
                        volume = volume
                    })
                end
            end
        end
    end
    
    nearbyVoices = newVoices
end

local function updateVoiceVolumes()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for i = 1, #nearbyVoices do
        local voice = nearbyVoices[i]
        local distance = #(playerCoords - GetEntityCoords(voice.ped))
        local newVolume = GetVoiceVolume(distance)
        
        if newVolume ~= voice.volume then
            voice.volume = newVolume
            
            SendReactMessage("voice:setVolume", {
                channel = voice.channel,
                volume = newVolume
            })
        end
    end
end

CreateThread(function()
    while true do
        Wait(1000)
        updateNearbyVoices()
    end
end)

CreateThread(function()
    while true do
        if #nearbyVoices > 0 then
            updateVoiceVolumes()
            Wait(50)
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent("phone:startedListening", function(source, channel)
    local playerId = GetPlayerFromServerId(source)
    
    if not playerId or playerId == 0 or playerId == PlayerId() then
        return
    end
    
    local playerPed = PlayerPedId()
    local targetPed = GetPlayerPed(playerId)
    local distance = #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed))
    
    if not DoesEntityExist(targetPed) or targetPed == playerPed or distance > 25.0 then
        return
    end
    
    for i = 1, #nearbyVoices do
        if nearbyVoices[i].source == source then
            return
        end
    end
    
    nearbyVoices[#nearbyVoices + 1] = {
        source = source,
        ped = targetPed,
        channel = channel,
        volume = GetVoiceVolume(distance)
    }
    
    SendReactMessage("voice:joinChannel", {
        channel = channel,
        volume = GetVoiceVolume(distance)
    })
end)

RegisterNetEvent("phone:stoppedListening", function(channel)
    SendReactMessage("voice:leaveChannel", channel)
end)

RegisterNUICallback("setListeningPeerId", function(peerId, callback)
    TriggerServerEvent("phone:setListeningPeerId", peerId)
    callback("ok")
end)

RegisterNUICallback("voice:getConfig", function(data, callback)
    callback({
        recordNearbyVoices = Config.Voice.RecordNearby,
        rtc = Config.RTCConfig
    })
end)