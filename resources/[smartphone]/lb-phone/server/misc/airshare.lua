local pendingAlbumShares = {}

BaseCallback("airShare:share", function(senderPlayerId, targetPlayerId, targetDevice, shareData)
    local senderName = Player(senderPlayerId).state.phoneName
    if not senderName then
        debugprint("No sender name")
        return false
    end
    
    shareData.sender = {
        name = senderName,
        source = senderPlayerId,
        device = "phone"
    }
    
    if targetDevice == "tablet" then
        if GetResourceState("lb-tablet") == "started" then
            if Player(targetPlayerId).state.lbTabletOpen then
                TriggerClientEvent("tablet:airShare:received", targetPlayerId, shareData)
            else
                return false
            end
        else
            return false
        end
    elseif targetDevice == "phone" then
        if not Player(targetPlayerId).state.phoneOpen then
            debugprint("sendToSource's phone is not open")
            return false
        end
        TriggerClientEvent("phone:airShare:received", targetPlayerId, shareData)
    end
    
    if shareData.type == "album" then
        if not pendingAlbumShares[targetPlayerId] then
            pendingAlbumShares[targetPlayerId] = {}
        end
        pendingAlbumShares[targetPlayerId][senderPlayerId] = shareData.album.id
    end
    
    return true
end, false)

RegisterNetEvent("phone:airShare:interacted", function(senderSource, senderDevice, accepted)
    local receiverSource = source
    
    if type(senderSource) ~= "number" or type(senderDevice) ~= "string" then
        debugprint("AirShare:interacted: Invalid senderSource or senderDevice", senderSource, senderDevice)
        return
    end
    
    if senderDevice == "tablet" then
        TriggerClientEvent("tablet:airShare:interacted", senderSource, receiverSource, accepted)
    elseif senderDevice == "phone" then
        TriggerClientEvent("phone:airShare:interacted", senderSource, receiverSource, accepted)
    end
    
    if pendingAlbumShares[receiverSource] and pendingAlbumShares[receiverSource][senderSource] then
        local albumId = pendingAlbumShares[receiverSource][senderSource]
        pendingAlbumShares[receiverSource][senderSource] = nil
        
        if not next(pendingAlbumShares[receiverSource]) then
            pendingAlbumShares[receiverSource] = nil
        end
        
        if not accepted then
            debugprint("AirShare: denied album share", albumId)
            return
        end
        
        debugprint("AirShare: accepted album share", albumId)
        HandleAcceptAirShareAlbum(receiverSource, senderSource, albumId)
    end
end)

local validShareTypes = {
    image = true,
    contact = true,
    location = true,
    note = true,
    voicememo = true
}

exports("AirShare", function(senderPlayerId, targetPlayerId, shareType, shareData)
    assert(type(senderPlayerId) == "number", "Invalid sender")
    assert(type(targetPlayerId) == "number", "Invalid target")
    assert(validShareTypes[shareType], "Invalid shareType")
    assert(type(shareData) == "table", "Invalid data")
    
    local senderPhoneNumber = GetEquippedPhoneNumber(senderPlayerId)
    if not senderPhoneNumber then
        return false
    end
    
    local airShareData = {
        type = shareType,
        sender = {
            name = Player(senderPlayerId) and Player(senderPlayerId).state.phoneName or senderPhoneNumber,
            source = senderPlayerId,
            device = "phone"
        }
    }
    
    if shareType == "image" then
        airShareData.attachment = shareData
        assert(shareData.src, "Invalid image data (missing src)")
        
        if not airShareData.attachment.timestamp then
            airShareData.attachment.timestamp = os.time() * 1000
        end
    elseif shareType == "contact" then
        airShareData.contact = shareData
        assert(type(airShareData.contact.number) == "string", "Invalid/missing contact data (contact.number)")
        assert(type(airShareData.contact.firstname) == "string", "Invalid/missing contact data (contact.firstname)")
    elseif shareType == "location" then
        assert(shareData.location, "Invalid location data (missing location)")
        assert(type(shareData.name) == "string", "Invalid/missing location data (location.name)")
        
        airShareData.location = shareData.location
        airShareData.name = shareData.name
    elseif shareType == "note" then
        airShareData.note = shareData
        assert(type(airShareData.note.title) == "string", "Invalid/missing note data (note.title)")
        assert(type(airShareData.note.content) == "string", "Invalid/missing note data (note.content)")
    elseif shareType == "voicememo" then
        airShareData.voicememo = shareData
        assert(type(airShareData.voicememo.title) == "string", "Invalid/missing voicememo data (voicememo.title)")
        assert(type(airShareData.voicememo.src) == "string", "Invalid/missing voicememo data (voicememo.src)")
        assert(type(airShareData.voicememo.duration) == "number", "Invalid/missing voicememo data (voicememo.duration)")
    end
    
    TriggerClientEvent("phone:airShare:received", targetPlayerId, airShareData)
end)

AddEventHandler("playerDropped", function()
    pendingAlbumShares[source] = nil
end)