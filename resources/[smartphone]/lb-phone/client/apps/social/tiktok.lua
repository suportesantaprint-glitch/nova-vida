local function formatVideoData(videoData)
    if videoData.metadata then
        videoData.metadata = json.decode(videoData.metadata)
    end
    
    if videoData.music then
        videoData.music = json.decode(videoData.music)
        local songData = Music.Songs[videoData.music.path]
        if songData then
            local albumData = Music.Albums[songData.album]
            if albumData and albumData.Cover then
                songData.Cover = albumData.Cover
            end
            videoData.music = {
                title = songData.Title,
                artist = songData.Artist,
                cover = songData.Cover,
                volume = videoData.music.volume,
                path = videoData.music.path
            }
        end
    end
    
    videoData.liked = videoData.liked == 1
    videoData.saved = videoData.saved == 1
    videoData.viewed = videoData.viewed == 1
    
    return videoData
end

RegisterNUICallback("TikTok", function(data, callback)
    if not currentPhone then
        return
    end
    
    local action = data.action
    debugprint("Trendy: " .. (action or ""))
    
    if action == "login" then
        local loginData = data.data
        TriggerCallback("tiktok:login", callback, loginData.username, loginData.password)
        
    elseif action == "signup" then
        local signupData = data.data
        TriggerCallback("tiktok:signup", callback, signupData.username, signupData.password, signupData.name)
        
    elseif action == "changePassword" then
        TriggerCallback("tiktok:changePassword", callback, data.oldPassword, data.newPassword)
        
    elseif action == "deleteAccount" then
        TriggerCallback("tiktok:deleteAccount", callback, data.password)
        
    elseif action == "logout" then
        TriggerCallback("tiktok:logout", callback)
        
    elseif action == "isLoggedIn" then
        TriggerCallback("tiktok:isLoggedIn", callback)
        
    elseif action == "getProfile" then
        TriggerCallback("tiktok:getProfile", callback, data.username)
        
    elseif action == "updateProfile" then
        TriggerCallback("tiktok:updateProfile", callback, data.data)
        
    elseif action == "searchAccounts" then
        TriggerCallback("tiktok:searchAccounts", callback, data.query, data.page)
        
    elseif action == "toggleFollow" then
        local followData = data.data
        TriggerCallback("tiktok:toggleFollow", callback, followData.username, followData.follow)
        
    elseif action == "getFollowing" then
        TriggerCallback("tiktok:getFollowing", callback, data.username, data.page)
        
    elseif action == "getFollowers" then
        TriggerCallback("tiktok:getFollowers", callback, data.username, data.page)
        
    elseif action == "uploadVideo" then
        local uploadData = data.data
        
        if not uploadData.src or not uploadData.caption then
            return callback({
                success = false,
                error = "invalid_caption"
            })
        end
        
        if uploadData.music and (not uploadData.music.path or not uploadData.music.volume) then
            return callback({
                success = false,
                error = "invalid_music"
            })
        end
        
        if uploadData.music then
            uploadData.music = json.encode(uploadData.music)
        end
        
        if uploadData.metadata then
            if type(uploadData.metadata) == "table" then
                local isEmpty = true
                for _, _ in pairs(uploadData.metadata) do
                    isEmpty = false
                    break
                end
                if isEmpty then
                    uploadData.metadata = nil
                else
                    uploadData.metadata = json.encode(uploadData.metadata)
                end
            end
        else
            uploadData.metadata = nil
        end
        
        TriggerCallback("tiktok:uploadVideo", callback, uploadData)
        
    elseif action == "deleteVideo" then
        TriggerCallback("tiktok:deleteVideo", callback, data.id)
        
    elseif action == "togglePinnedVideo" then
        TriggerCallback("tiktok:togglePinnedVideo", callback, data.id, data.toggle)
        
    elseif action == "getVideos" then
        TriggerCallback("tiktok:getVideos", function(videos)
            for i = 1, #videos do
                videos[i] = formatVideoData(videos[i])
            end
            callback(videos)
        end, data.data, data.page or 0)
        
    elseif action == "getVideo" then
        TriggerCallback("tiktok:getVideo", function(result)
            if result.video then
                result.video = formatVideoData(result.video)
            end
            callback(result)
        end, data.id)
        
    elseif action == "setViewed" then
        TriggerServerEvent("phone:tiktok:setViewed", data.id)
        callback("ok")
        
    elseif action == "toggleLike" then
        TriggerCallback("tiktok:toggleVideoAction", callback, "like", data.id, data.toggle)
        
    elseif action == "toggleSave" then
        TriggerCallback("tiktok:toggleVideoAction", callback, "save", data.id, data.toggle)
        
    elseif action == "postComment" then
        local commentData = data.data
        TriggerCallback("tiktok:postComment", callback, commentData.id, commentData.replyTo, commentData.comment)
        
    elseif action == "getComments" then
        TriggerCallback("tiktok:getComments", callback, data.data.id, data.data.replyTo, data.data.creator, data.page)
        
    elseif action == "deleteComment" then
        TriggerCallback("tiktok:deleteComment", callback, data.id, data.videoId)
        
    elseif action == "setPinnedComment" then
        TriggerCallback("tiktok:setPinnedComment", callback, data.commentId, data.videoId)
        
    elseif action == "toggleLikeComment" then
        TriggerCallback("tiktok:toggleLikeComment", callback, data.id, data.toggle)
        
    elseif action == "getRecentMessages" then
        TriggerCallback("tiktok:getRecentMessages", callback)
        
    elseif action == "getMessages" then
        TriggerCallback("tiktok:getMessages", callback, data.id, data.page)
        
    elseif action == "sendMessage" then
        if not CanInteract() then
            return callback(false)
        end
        TriggerCallback("tiktok:sendMessage", callback, data.data)
        
    elseif action == "getChannelId" then
        TriggerCallback("tiktok:getChannelId", callback, data.username)
        
    elseif action == "getNotifications" then
        TriggerCallback("tiktok:getNotifications", callback, data.page)
        
    elseif action == "getUnreadMessages" then
        TriggerCallback("tiktok:getUnreadMessages", callback)
        
    elseif action == "clearUnreadMessages" then
        TriggerServerEvent("phone:tiktok:clearUnreadMessages", data.id)
    end
end)

RegisterNetEvent("phone:tiktok:updateFollowers", function(username, method)
    SendReactMessage("tiktok:updateFollowers", {
        username = username,
        method = method
    })
end)

RegisterNetEvent("phone:tiktok:updateFollowing", function(username, method)
    SendReactMessage("tiktok:updateFollowing", {
        username = username,
        method = method
    })
end)

RegisterNetEvent("phone:tiktok:updateVideoStats", function(statType, videoId, method, count)
    local updateData = {
        id = videoId,
        method = method,
        count = count
    }
    
    if statType == "like" then
        SendReactMessage("tiktok:updateLikes", updateData)
    elseif statType == "save" then
        SendReactMessage("tiktok:updateSaves", updateData)
    elseif statType == "comment" then
        SendReactMessage("tiktok:updateComments", updateData)
    end
end)

RegisterNetEvent("phone:tiktok:updateCommentStats", function(statType, commentId, method)
    if statType == "reply" then
        SendReactMessage("tiktok:updateReplies", {
            id = commentId,
            method = method
        })
    elseif statType == "like" then
        SendReactMessage("tiktok:updateCommentLikes", {
            id = commentId,
            method = method
        })
    end
end)

RegisterNetEvent("phone:tiktok:receivedMessage", function(messageData)
    SendReactMessage("tiktok:receivedMessage", messageData)
end)

RegisterNetEvent("phone:tiktok:newVideo", function(videoData)
    TriggerEvent("lb-phone:trendy:newPost", videoData)
end)