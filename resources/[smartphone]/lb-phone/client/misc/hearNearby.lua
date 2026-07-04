if not Config.Voice.HearNearby then
    return
end

local nearbyLiveStreams = {}

local function enterLiveProximity(liveId)
    if not nearbyLiveStreams[liveId] then
        nearbyLiveStreams[liveId] = true
        debugprint("entered live", liveId)
        TriggerServerEvent("phone:instagram:enteredLiveProximity", liveId)
    end
end

local function leaveLiveProximity(liveId)
    if nearbyLiveStreams[liveId] then
        nearbyLiveStreams[liveId] = nil
        debugprint("left live 1", liveId)
        TriggerServerEvent("phone:instagram:leftLiveProximity", liveId)
    end
end

RegisterNetEvent("phone:instagram:endLive", function(liveId, playerId)
    if not playerId then
        nearbyLiveStreams[liveId] = nil
        debugprint("left live 2", liveId)
        return
    end
    
    if nearbyLiveStreams[liveId] then
        nearbyLiveStreams[liveId] = nil
        TriggerServerEvent("phone:instagram:leftLiveProximity", playerId, true)
    end
end)

local listeningToPlayers = {}

local function startListeningToPlayer(playerId)
    if not playerId or table.contains(listeningToPlayers, playerId) then
        return
    end
    
    debugprint("started listening to", playerId)
    TriggerServerEvent("phone:phone:listenToPlayer", playerId)
    listeningToPlayers[#listeningToPlayers + 1] = playerId
    
    return true
end

local function stopListeningToPlayer(playerId)
    if not playerId then
        return
    end
    
    local playerIndex = table.contains(listeningToPlayers, playerId)
    if not playerIndex then
        return
    end
    
    debugprint("stopped listening to", playerId)
    TriggerServerEvent("phone:phone:stopListeningToPlayer", playerId)
    table.remove(listeningToPlayers, playerIndex)
    
    return true
end

local callProximityPlayers = {}

local function enterCallProximity(playerId)
    local playerIndex = table.contains(callProximityPlayers, playerId)
    if not playerIndex then
        return
    end
    
    debugprint("started talking to", playerId)
    TriggerServerEvent("phone:phone:leftCallProximity", playerId)
    table.remove(callProximityPlayers, playerIndex)
    
    return true
end

local function leaveCallProximity(playerId)
    if not playerId or table.contains(callProximityPlayers, playerId) then
        return
    end
    
    debugprint("stopped talking to", playerId)
    TriggerServerEvent("phone:phone:enteredCallProximity", playerId)
    callProximityPlayers[#callProximityPlayers + 1] = playerId
    
    return true
end

while true do
    Wait(250)
    
    local nearbyPlayers = GetNearbyPlayers()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for i = 1, #nearbyPlayers do
        local player = nearbyPlayers[i]
        local playerState = Player(player.source).state
        
        local isOnCall = playerState.onCallWith and playerState.speakerphone and playerState.callAnswered
        local isLiveStreaming = playerState.instapicIsLive
        
        local distance = #(playerCoords - GetEntityCoords(player.ped))
        
        if distance <= 5 then
            if isLiveStreaming then
                enterLiveProximity(isLiveStreaming)
            end
            
            if isOnCall then
                if playerState.otherMutedCall then
                    if stopListeningToPlayer(playerState.onCallWith) then
                        if not playerState.mutedCall then
                            TriggerServerEvent("phone:phone:enteredCallProximity", player.source)
                        end
                    end
                else
                    startListeningToPlayer(playerState.onCallWith)
                end
                
                if playerState.mutedCall then
                    if enterCallProximity(player.source) then
                        if not playerState.otherMutedCall then
                            TriggerServerEvent("phone:phone:listenToPlayer", playerState.onCallWith)
                        end
                    end
                else
                    leaveCallProximity(player.source)
                end
            else
                if playerState.onCallWith then
                    stopListeningToPlayer(playerState.onCallWith)
                    enterCallProximity(player.source)
                end
            end
        elseif isLiveStreaming then
            leaveLiveProximity(isLiveStreaming)
        else
            if playerState.onCallWith then
                stopListeningToPlayer(playerState.onCallWith)
                enterCallProximity(player.source)
            end
        end
    end
end