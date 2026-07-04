local isLive = false
local currentWatchingUser = nil
local watchingSources = {}

local interactionRequiredActions = {
    "sendLiveMessage",
    "logIn", 
    "toggleFollow",
    "toggleLike",
    "postComment",
    "sendMessage"
}

RegisterNUICallback("Instagram", function(data, callback)
    if not currentPhone then
        return
    end
    
    local action = data.action
    debugprint("InstaPic: " .. (action or ""))
    
    if table.contains(interactionRequiredActions, action) then
        if not CanInteract() then
            return callback(false)
        end
    end
    
    if action == "getLives" then
        TriggerCallback("instagram:getLives", callback)
        
    elseif action == "getLiveViewers" then
        TriggerCallback("instagram:getLiveViewers", callback, data.username)
        
    elseif action == "goLive" then
        local canGoLive = AwaitCallback("instagram:canGoLive")
        if not canGoLive then
            debugprint("Não permitido iniciar live")
            callback(false)
            return
        end
        debugprint("Permitido iniciar live; configurando UI")
        callback(true)
        
    elseif action == "setLive" then
        debugprint("Enviando evento do servidor para iniciar livestream")
        TriggerServerEvent("phone:instagram:startLive", data.id)
        isLive = true
        EnableWalkableCam()
        
    elseif action == "endLive" then
        EndLive()
        callback(true)
        
    elseif action == "viewLive" then
        local liveData = AwaitCallback("instagram:viewLive", data.username)
        if not liveData then
            return callback(false)
        end
        
        local volume = 0.5
        if settings and settings.sound and settings.sound.volume then
            volume = settings.sound.volume
        end
        
        currentWatchingUser = data.username
        
        table.insert(watchingSources, liveData.host)
        
        for i = 1, #liveData.participants do
            table.insert(watchingSources, liveData.participants[i].source)
        end
        
        debugprint("InstaPic: adicionando voice targets. Volume:", volume)
        
        MumbleClearVoiceTargetPlayers(1)
        for i = 1, #watchingSources do
            local source = watchingSources[i]
            MumbleAddVoiceTargetPlayerByServerId(1, source)
            MumbleSetVolumeOverrideByServerId(source, volume)
            debugprint("Começou a escutar", source)
        end
        
        callback(#liveData.viewers)
        
    elseif action == "stopViewing" then
        AwaitCallback("instagram:stopViewing", data.username)
        
        MumbleClearVoiceTargetPlayers(1)
        for i = 1, #watchingSources do
            MumbleSetVolumeOverrideByServerId(watchingSources[i], -1.0)
            debugprint("Parou de escutar", watchingSources[i])
        end
        
        currentWatchingUser = nil
        watchingSources = {}
        
    elseif action == "sendLiveMessage" then
        TriggerServerEvent("phone:instagram:sendLiveMessage", data.data)
        
    elseif action == "addCall" then
        TriggerServerEvent("phone:instagram:addCall", data.id)
        
    elseif action == "inviteLive" then
        TriggerServerEvent("phone:instagram:inviteLive", data.username)
        
    elseif action == "removeLive" then
        TriggerServerEvent("phone:instagram:removeLive", data.username)
        
    elseif action == "joinLive" then
        local success = AwaitCallback("instagram:joinLive", data.username, data.streamId)
        callback(success)
        if not success then
            return
        end
        isLive = true
        EnableWalkableCam()
    end
    
    if action == "addToStory" then
        local canCreateStory = AwaitCallback("instagram:canCreateStory")
        if not canCreateStory then
            debugprint("Não permitido criar story")
            callback(false)
            return
        end
        debugprint("Permitido criar story")
        TriggerCallback("instagram:addToStory", callback, data.media, data.metadata)
        
    elseif action == "removeFromStory" then
        TriggerCallback("instagram:removeFromStory", callback, data.id)
        
    elseif action == "getStories" then
        TriggerCallback("instagram:getStories", callback)
        
    elseif action == "getStory" then
        TriggerCallback("instagram:getStory", callback, data.username)
        
    elseif action == "getViewers" then
        TriggerCallback("instagram:getViewers", callback, data.id, data.page)
        
    elseif action == "viewedStory" then
        TriggerCallback("instagram:viewedStory", callback, data.id)
    end
    
    if action == "flipCamera" then
        ToggleSelfieCam(not IsSelfieCam())
    end
    
    if action == "createAccount" then
        TriggerCallback("instagram:createAccount", callback, data.name, data.username, data.password)
        
    elseif action == "changePassword" then
        TriggerCallback("instagram:changePassword", callback, data.oldPassword, data.newPassword)
        
    elseif action == "deleteAccount" then
        TriggerCallback("instagram:deleteAccount", callback, data.password)
        
    elseif action == "logIn" then
        TriggerCallback("instagram:logIn", callback, data.username, data.password)
        
    elseif action == "signOut" then
        TriggerCallback("instagram:signOut", callback)
        
    elseif action == "isLoggedIn" then
        TriggerCallback("instagram:isLoggedIn", callback)
    end
    
    if action == "getProfile" then
        TriggerCallback("instagram:getProfile", callback, data.username)
        
    elseif action == "updateProfile" then
        TriggerCallback("instagram:updateProfile", callback, data.data)
        
    elseif action == "getFollowers" then
        TriggerCallback("instagram:getData", callback, "followers", data.data)
        
    elseif action == "getFollowing" then
        TriggerCallback("instagram:getData", callback, "following", data.data)
        
    elseif action == "getLikes" then
        TriggerCallback("instagram:getData", callback, "likes", data.data)
        
    elseif action == "toggleFollow" then
        TriggerCallback("instagram:toggleFollow", callback, data.data.username, data.data.following)
    end
    
    if action == "newPost" then
        local images = json.encode(data.data.images)
        TriggerCallback("instagram:createPost", callback, images, data.data.caption, data.data.location)
        
    elseif action == "deletePost" then
        TriggerCallback("instagram:deletePost", callback, data.id)
        
    elseif action == "getPosts" then
        TriggerCallback("instagram:getPosts", callback, data.filters, data.page)
        
    elseif action == "getPost" then
        TriggerCallback("instagram:getPost", callback, data.id)
        
    elseif action == "toggleLike" then
        TriggerCallback("instagram:toggleLike", callback, data.data.postId, data.data.toggle, data.data.isComment)
    end
    
    if action == "getComments" then
        local page = data.page or 0
        local comments = AwaitCallback("instagram:getComments", data.postId, page)
        
        local formattedComments = {}
        for i = 1, #comments do
            local comment = comments[i]
            formattedComments[i] = {
                user = {
                    username = comment.username,
                    avatar = comment.profile_image,
                    verified = comment.verified
                },
                comment = {
                    content = comment.comment,
                    timestamp = comment.timestamp,
                    likes = comment.like_count,
                    liked = comment.liked,
                    id = comment.id
                }
            }
        end
        
        callback(formattedComments)
        
    elseif action == "postComment" then
        TriggerCallback("instagram:postComment", callback, data.data.postId, data.data.comment)
    end
    
    if action == "getNotifications" then
        local page = data.page or 0
        TriggerCallback("instagram:getNotifications", callback, page)
        
    elseif action == "getFollowRequests" then
        local page = data.page or 0
        TriggerCallback("instagram:getFollowRequests", callback, page)
        
    elseif action == "handleFollowRequest" then
        TriggerCallback("instagram:handleFollowRequest", callback, data.username, data.accept)
    end
    
    if action == "getRecentMessages" then
        local messages = AwaitCallback("instagram:getRecentMessages", data.page)
        
        for i = 1, #messages do
            if messages[i].attachments then
                messages[i].attachments = json.decode(messages[i].attachments)
            end
        end
        
        callback(messages)
        
    elseif action == "getMessages" then
        local messages = AwaitCallback("instagram:getMessages", data.username, data.page)
        
        for i = 1, #messages do
            if messages[i].attachments then
                messages[i].attachments = json.decode(messages[i].attachments)
            end
        end
        
        callback(messages)
        
    elseif action == "sendMessage" then
        TriggerCallback("instagram:sendMessage", callback, data.username, data.message)
        
    elseif action == "search" then
        TriggerCallback("instagram:search", callback, data.query)
    end
end)

RegisterNetEvent("phone:instagram:addLiveMessage", function(messageData)
    SendReactMessage("instagram:addMessage", messageData)
end)

RegisterNetEvent("phone:instagram:updateLives", function(livesData)
    SendReactMessage("instagram:updateLives", livesData)
end)

RegisterNetEvent("phone:instagram:endLive", function(username)
    if username == currentWatchingUser then
        MumbleClearVoiceTargetPlayers(1)
        for i = 1, #watchingSources do
            MumbleSetVolumeOverrideByServerId(watchingSources[i], -1.0)
            debugprint("InstaPic endLive: parou de escutar", watchingSources[i])
        end
        currentWatchingUser = nil
        watchingSources = {}
    end
    
    SendReactMessage("instagram:liveEnded", username)
end)

RegisterNetEvent("phone:instagram:joinedLive", function(joinData)
    SendReactMessage("instagram:joinedLive", joinData)
    
    local playerSource = GetPlayerServerId(PlayerId())
    if joinData.source == playerSource then return end
    
    table.insert(watchingSources, joinData.source)
    
    local volume = 0.5
    if settings and settings.sound and settings.sound.volume then
        volume = settings.sound.volume
    end
    
    MumbleAddVoiceTargetPlayerByServerId(1, joinData.source)
    MumbleSetVolumeOverrideByServerId(joinData.source, volume)
    debugprint("InstaPic joinedLive: começou a escutar", joinData.source, "volume:", volume)
end)

AddEventHandler("lb-phone:settingsUpdated", function()
    if not currentWatchingUser or #watchingSources == 0 then
        return
    end
    
    local volume = 0.5
    if settings and settings.sound and settings.sound.volume then
        volume = settings.sound.volume
    end
    
    for i = 1, #watchingSources do
        local source = watchingSources[i]
        local playerSource = GetPlayerServerId(PlayerId())
        
        if source ~= playerSource then
            MumbleSetVolumeOverrideByServerId(source, volume)
            debugprint("InstaPic settingsUpdated: definir volume para", volume, "para", source)
        end
    end
end)

RegisterNetEvent("phone:instagram:leftLive", function(host, participant, participantSource)
    SendReactMessage("instagram:leftLive", {
        host = host,
        participant = participant
    })
    
    local playerSource = GetPlayerServerId(PlayerId())
    if participantSource == playerSource then return end
    
    for i = 1, #watchingSources do
        if watchingSources[i] == participantSource then
            MumbleSetVolumeOverrideByServerId(participantSource, -1.0)
            MumbleRemoveVoiceTargetPlayerByServerId(1, participantSource)
            debugprint("InstaPic leftLive: parou de escutar", participantSource)
            table.remove(watchingSources, i)
            break
        end
    end
end)

RegisterNetEvent("phone:instagram:endCall", function(callData)
    SendReactMessage("instagram:endCall", callData)
end)

RegisterNetEvent("phone:instagram:updateViewers", function(username, viewers)
    SendReactMessage("instagram:updateViewers", {
        username = username,
        viewers = viewers
    })
end)

RegisterNetEvent("phone:instagram:updateProfileData", function(username, data, increment)
    debugprint("updateProfileData", username, data, increment)
    SendReactMessage("instagram:updateProfileData", {
        username = username,
        data = data,
        increment = increment
    })
end)

RegisterNetEvent("phone:instagram:updatePostData", function(postId, data, increment)
    debugprint("updatePostData", postId, data, increment)
    SendReactMessage("instagram:updatePostData", {
        postId = postId,
        data = data,
        increment = increment
    })
end)

RegisterNetEvent("phone:instagram:updateCommentLikes", function(commentId, increment)
    debugprint("updateCommentLikes", commentId, increment)
    SendReactMessage("instagram:updateCommentLikes", {
        commentId = commentId,
        increment = increment
    })
end)

RegisterNetEvent("phone:instagram:newMessage", function(messageData)
    SendReactMessage("instagram:newMessage", messageData)
end)

RegisterNetEvent("phone:instagram:invitedLive", function(inviteData)
    SendReactMessage("instagram:invitedLive", inviteData)
end)

RegisterNetEvent("phone:instagram:removedLive", function()
    EndLive()
end)

RegisterNetEvent("phone:instagram:newPost", function(postData)
    TriggerEvent("lb-phone:instapic:newPost", postData)
end)

function EndLive()
    if not isLive then
        return
    end
    
    isLive = false
    DisableWalkableCam()
    AwaitCallback("instagram:endLive")
end

function IsLive()
    return isLive
end

function IsWatchingLive()
    return currentWatchingUser
end

exports("IsLive", IsLive)