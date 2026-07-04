local LiveData = {}
local PhoneCalls = {}

function GetLoggedInInstagramUser(source)
    local phoneNumber = GetEquippedPhoneNumber(source)
    if not phoneNumber then
        return false
    end
    
    return GetLoggedInAccount(phoneNumber, "Instagram")
end

function GetLoggedInPhoneNumbers(username)
    local phoneNumbers = {}
    local result = MySQL.query.await(
        "SELECT phone_number FROM phone_logged_in_accounts WHERE app = 'Instagram' AND `active` = 1 AND username = ?",
        {username}
    )
    
    for i = 1, #result do
        phoneNumbers[i] = result[i].phone_number
    end
    
    return phoneNumbers
end

function InstagramBaseCallback(callbackName, callback, fallback)
    BaseCallback("instagram:" .. callbackName, function(source, phoneNumber, ...)
        local username = GetLoggedInAccount(phoneNumber, "Instagram")
        if not username then
            return fallback
        end
        
        return callback(source, phoneNumber, username, ...)
    end, fallback)
end

function NotifyLoggedInUsers(username, notification, excludeNumber)
    local phoneNumbers = GetLoggedInPhoneNumbers(username)
    notification.app = "Instagram"
    
    for i = 1, #phoneNumbers do
        local phoneNumber = phoneNumbers[i]
        if phoneNumber ~= excludeNumber then
            SendNotification(phoneNumber, notification)
        end
    end
end

RegisterLegacyCallback("instagram:getLives", function(source, callback)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback({})
    end
    
    local filteredLives = {}
    for liveUsername, liveData in pairs(LiveData) do
        local canView = true
        
        if liveData.private then
            local isFollowing = MySQL.Sync.fetchScalar(
                "SELECT TRUE FROM phone_instagram_follows WHERE follower=@follower AND followed=@followed",
                {["@follower"] = username, ["@followed"] = liveUsername}
            )
            canView = isFollowing
        end
        
        if canView then
            filteredLives[liveUsername] = liveData
        end
    end
    
    callback(filteredLives)
end)

RegisterLegacyCallback("instagram:getLiveViewers", function(source, callback, liveUsername)
    local liveData = LiveData[liveUsername]
    if not liveData then
        return callback({})
    end
    
    local viewers = {}
    for i = 1, #liveData.viewers do
        local viewerSource = liveData.viewers[i]
        local phoneNumber = GetEquippedPhoneNumber(viewerSource)
        
        if phoneNumber then
            local viewerData = MySQL.Sync.fetchAll([[
                SELECT
                    a.profile_image AS avatar, a.verified, a.display_name AS `name`, a.username
                FROM phone_logged_in_accounts l
                INNER JOIN phone_instagram_accounts a ON l.username = a.username
                WHERE l.phone_number = ? AND l.active = 1 AND l.app = 'Instagram'
            ]], {phoneNumber})
            
            if viewerData and viewerData[1] then
                viewers[#viewers + 1] = viewerData[1]
            end
        end
    end
    
    callback(viewers)
end)

RegisterLegacyCallback("instagram:canGoLive", function(source, callback)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback(false)
    end
    
    local canLive, errorMessage = CanGoLive(source, username)
    if not canLive then
        local phoneNumber = GetEquippedPhoneNumber(source)
        if phoneNumber then
            SendNotification(phoneNumber, {
                app = "Instagram",
                title = errorMessage or L("BACKEND.INSTAGRAM.NOT_ALLOWED_LIVE")
            })
        end
    end
    
    callback(canLive)
end)

RegisterLegacyCallback("instagram:canCreateStory", function(source, callback)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback(false)
    end
    
    local canCreate, errorMessage = CanCreateStory(source, username)
    if not canCreate then
        local phoneNumber = GetEquippedPhoneNumber(source)
        if phoneNumber then
            SendNotification(phoneNumber, {
                app = "Instagram",
                title = errorMessage or L("BACKEND.INSTAGRAM.NOT_ALLOWED_STORY")
            })
        end
    end
    
    callback(canCreate)
end)

RegisterNetEvent("phone:instagram:startLive", function(liveId)
    local source = source
    local username = GetLoggedInInstagramUser(source)
    
    if not username or LiveData[username] or not CanGoLive(source, username) then
        return
    end
    
    local accountData = MySQL.single.await(
        "SELECT profile_image, verified, display_name, private FROM phone_instagram_accounts WHERE username = ?",
        {username}
    )
    
    if not accountData then
        return
    end
    
    LiveData[username] = {
        id = liveId,
        avatar = accountData.profile_image,
        verified = accountData.verified,
        name = accountData.display_name,
        private = accountData.private,
        host = source,
        viewers = {},
        nearby = {},
        invites = {},
        participants = {}
    }
    
    Player(source).state.instapicIsLive = username
    
    TriggerClientEvent("phone:instagram:updateLives", -1, LiveData)
    
    Log("InstaPic", source, "success", 
        L("BACKEND.LOGS.LIVE_TITLE"),
        L("BACKEND.LOGS.STARTED_LIVE", {username = username})
    )
    
    TrackSimpleEvent("go_live")
    
    local notification = {
        title = L("APPS.INSTAGRAM.TITLE"),
        content = L("BACKEND.INSTAGRAM.STARTED_LIVE", {username = username})
    }
    
    if Config.InstaPicLiveNotifications then
        local notifyType = Config.InstaPicLiveNotifications == "all" and "all" or "online"
        NotifyEveryone(notifyType, {
            app = "Instagram",
            title = notification.title,
            content = notification.content
        })
    else
        local followers = MySQL.query.await(
            "SELECT follower FROM phone_instagram_follows WHERE followed = ?",
            {username}
        )
        
        for i = 1, #followers do
            NotifyLoggedInUsers(followers[i].follower, notification)
        end
    end
end)

function CleanupLiveWithParticipants(liveData)
    if not liveData.participants then
        return
    end
    
    local allViewers = table.clone(liveData.viewers)
    allViewers[#allViewers + 1] = liveData.host
    
    for i = 1, #liveData.participants do
        local participant = liveData.participants[i]
        if participant and participant.username then
            local participantLive = LiveData[participant.username]
            if participantLive then
                TriggerClientEvent("phone:phone:removeVoiceTarget", participantLive.host, allViewers)
                Player(participantLive.host).state.instapicIsLive = nil
                LiveData[participant.username] = nil
                TriggerClientEvent("phone:instagram:endLive", -1, participant.username)
            end
        end
    end
    
    for i = 1, #liveData.nearby do
        local nearbySource = liveData.nearby[i]
        if nearbySource then
            TriggerClientEvent("phone:phone:removeVoiceTarget", nearbySource, allViewers)
            TriggerClientEvent("phone:instagram:leftProximity", -1, nearbySource, liveData.host)
        end
    end
    
    TriggerClientEvent("phone:phone:removeVoiceTarget", liveData.host, liveData.viewers)
end

function RemoveParticipantFromLive(hostUsername, participantUsername)
    local liveData = LiveData[hostUsername]
    local participantSource = nil
    
    if not liveData or not liveData.participants then
        return
    end
    
    local found = false
    for i = 1, #liveData.participants do
        local participant = liveData.participants[i]
        if participant.username == participantUsername then
            participantSource = participant.source
            table.remove(liveData.participants, i)
            found = true
            break
        end
    end
    
    if not found then
        return
    end
    
    local allViewers = table.clone(liveData.viewers)
    allViewers[#allViewers + 1] = liveData.host
    
    for i = 1, #allViewers do
        TriggerClientEvent("phone:instagram:leftLive", allViewers[i], hostUsername, participantUsername, participantSource)
    end
    
    local remainingViewers = table.clone(liveData.viewers)
    for i = 1, #liveData.participants do
        for j = 1, #remainingViewers do
            if remainingViewers[j] == liveData.participants[i].source then
                table.remove(remainingViewers, j)
                break
            end
        end
    end
    
    TriggerClientEvent("phone:phone:removeVoiceTarget", participantSource, remainingViewers)
end

RegisterLegacyCallback("instagram:endLive", function(source, callback)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback(true)
    end
    
    local liveData = LiveData[username]
    if not liveData then
        return callback(true)
    end
    
    local participantHost = liveData.participant
    if participantHost then
        RemoveParticipantFromLive(participantHost, username)
    else
        CleanupLiveWithParticipants(liveData)
    end
    
    LiveData[username] = nil
    Player(source).state.instapicIsLive = nil
    
    TriggerClientEvent("phone:instagram:updateLives", -1, LiveData)
    TriggerClientEvent("phone:instagram:endLive", -1, username, participantHost)
    
    Log("InstaPic", source, "error",
        L("BACKEND.LOGS.LIVE_TITLE"),
        L("BACKEND.LOGS.ENDED_LIVE", {username = username})
    )
    
    callback(true)
end)

AddEventHandler("playerDropped", function()
    local source = source
    
    for liveUsername, liveData in pairs(LiveData) do
        for i, viewerSource in pairs(liveData.viewers) do
            if viewerSource == source then
                if PhoneCalls[source] then
                    TriggerClientEvent("phone:endCall", liveData.host, PhoneCalls[source])
                    PhoneCalls[source] = nil
                end
                
                table.remove(liveData.viewers, i)
                TriggerClientEvent("phone:instagram:updateViewers", -1, liveUsername, #liveData.viewers)
            end
        end
        
        if liveData.host == source then
            local participantHost = liveData.participant
            if participantHost then
                RemoveParticipantFromLive(participantHost, liveUsername)
            else
                CleanupLiveWithParticipants(liveData)
            end
            
            LiveData[liveUsername] = nil
            TriggerClientEvent("phone:instagram:updateLives", -1, LiveData)
            TriggerClientEvent("phone:instagram:endLive", -1, liveUsername, participantHost)
            
            if liveData.host == source then
                return
            end
        end
    end
end)

RegisterNetEvent("phone:instagram:addCall", function(callData)
    local source = source
    local isViewing = false
    
    for _, liveData in pairs(LiveData) do
        for _, viewerSource in pairs(liveData.viewers) do
            if viewerSource == source then
                isViewing = true
                break
            end
        end
    end
    
    if not PhoneCalls[source] and isViewing then
        PhoneCalls[source] = callData
    end
end)

RegisterLegacyCallback("instagram:viewLive", function(source, callback, liveUsername)
    local liveData = LiveData[liveUsername]
    if not liveData then
        return callback(false)
    end
    
    local alreadyViewing = false
    for i = 1, #liveData.viewers do
        if liveData.viewers[i] == source then
            alreadyViewing = true
            break
        end
    end
    
    if not alreadyViewing then
        liveData.viewers[#liveData.viewers + 1] = source
        
        TriggerClientEvent("phone:phone:addVoiceTarget", liveData.host, source)
        TriggerClientEvent("phone:instagram:updateViewers", -1, liveUsername, #liveData.viewers)
        
        for i = 1, #liveData.participants do
            TriggerClientEvent("phone:phone:addVoiceTarget", liveData.participants[i].source, source)
        end
        
        SetTimeout(500, function()
            local nearbyUsers = liveData.nearby or {}
            for i = 1, #nearbyUsers do
                TriggerClientEvent("phone:phone:addVoiceTarget", nearbyUsers[i], source)
                TriggerClientEvent("phone:instagram:enteredProximity", source, nearbyUsers[i], liveData.host)
            end
        end)
    end
    
    callback(liveData)
end)

RegisterLegacyCallback("instagram:stopViewing", function(source, callback, liveUsername)
    local liveData = LiveData[liveUsername]
    if not liveData then
        return callback()
    end
    
    local wasViewing = false
    
    for i, viewerSource in pairs(liveData.viewers) do
        if viewerSource == source then
            wasViewing = true
            
            if PhoneCalls[source] then
                TriggerClientEvent("phone:instagram:endCall", liveData.host, PhoneCalls[source])
                PhoneCalls[source] = nil
            end
            
            table.remove(liveData.viewers, i)
            break
        end
    end
    
    for i = 1, #liveData.nearby do
        local nearbySource = liveData.nearby[i]
        if nearbySource then
            TriggerClientEvent("phone:phone:removeVoiceTarget", nearbySource, source)
            TriggerClientEvent("phone:instagram:leftProximity", source, nearbySource, liveData.host)
        end
    end
    
    if wasViewing then
        TriggerClientEvent("phone:phone:removeVoiceTarget", liveData.host, source)
        TriggerClientEvent("phone:instagram:updateViewers", -1, liveUsername, #liveData.viewers)
        
        for i = 1, #liveData.participants do
            TriggerClientEvent("phone:phone:removeVoiceTarget", liveData.participants[i].source, source)
        end
    end
    
    callback()
end)

RegisterNetEvent("phone:instagram:inviteLive", function(inviteeUsername)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return
    end
    
    local liveData = LiveData[username]
    if not liveData or not liveData.participants then
        return
    end
    
    if LiveData[inviteeUsername] then
        return
    end
    
    if #liveData.participants >= 3 then
        return
    end
    
    for i = 1, #liveData.participants do
        if liveData.participants[i] and liveData.participants[i].username == inviteeUsername then
            return
        end
    end
    
    if not liveData.invites[inviteeUsername] then
        liveData.invites[inviteeUsername] = true
    end

    local activeAccounts = GetActiveAccounts("Instagram")
    for phoneNumber, accountUsername in pairs(activeAccounts) do
        if inviteeUsername == accountUsername then
            local targetSource = GetSourceFromNumber(phoneNumber)
            if targetSource then
                TriggerClientEvent("phone:instagram:invitedLive", targetSource, username)
            end
        end
    end
end)

RegisterNetEvent("phone:instagram:removeLive", function(participantUsername)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return
    end
    
    local liveData = LiveData[username]
    if not liveData then
        return
    end
    
    local found = false
    local participantSource = nil
    
    for i = 1, #liveData.participants do
        local participant = liveData.participants[i]
        if participant.username == participantUsername then
            found = true
            participantSource = participant.source
            break
        end
    end
    
    if found and participantSource then
        RemoveParticipantFromLive(username, participantUsername)
        LiveData[participantUsername] = nil
        Player(participantSource).state.instapicIsLive = nil
        
        TriggerClientEvent("phone:instagram:updateLives", -1, LiveData)
        TriggerClientEvent("phone:instagram:endLive", -1, participantUsername, username)
        TriggerClientEvent("phone:instagram:removedLive", participantSource)
    end
    
    TriggerClientEvent("phone:instagram:updateLives", -1, LiveData)
end)

RegisterLegacyCallback("instagram:joinLive", function(source, callback, hostUsername, liveId)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback(false)
    end
    
    local hostLive = LiveData[hostUsername]
    if not hostLive or not hostLive.participants then
        return callback(false)
    end
    
    if LiveData[username] then
        return callback(false)
    end
    
    if hostLive.invites[username] then
        hostLive.invites[username] = nil
    end
    
    if #hostLive.participants >= 3 then
        return callback(false)
    end
    
    for i = 1, #hostLive.participants do
        if hostLive.participants[i] and hostLive.participants[i].username == username then
            return callback(false)
        end
    end
    
    local accountData = MySQL.Sync.fetchAll(
        "SELECT profile_image, verified, display_name FROM phone_instagram_accounts WHERE username=@username",
        {["@username"] = username}
    )
    
    local account = accountData[1]
    if not account then
        return callback(false)
    end
    
    hostLive.participants[#hostLive.participants + 1] = {
        username = username,
        name = account.display_name,
        avatar = account.profile_image,
        verified = account.verified,
        id = liveId,
        source = source
    }
    
    LiveData[username] = {
        id = liveId,
        avatar = account.profile_image,
        verified = account.verified,
        name = account.display_name,
        host = source,
        nearby = {},
        viewers = {},
        participant = hostUsername
    }
    
    Player(source).state.instapicIsLive = username
    TriggerClientEvent("phone:instagram:updateLives", -1, LiveData)
    
    local followers = MySQL.Sync.fetchAll(
        "SELECT follower FROM phone_instagram_follows WHERE followed = @username",
        {["@username"] = username}
    )
    
    for i = 1, #followers do
        local followerNumbers = GetLoggedInPhoneNumbers(followers[i].follower)
        for j = 1, #followerNumbers do
            SendNotification(followerNumbers[j], {
                app = "Instagram",
                title = L("APPS.INSTAGRAM.TITLE"),
                content = L("BACKEND.INSTAGRAM.JOINED_LIVE", {
                    invitee = username,
                    inviter = hostUsername
                })
            })
        end
    end
    
    local allViewers = table.clone(LiveData[hostUsername].viewers)
    allViewers[#allViewers + 1] = LiveData[hostUsername].host
    
    TriggerClientEvent("phone:phone:addVoiceTarget", source, allViewers)
    
    for i = 1, #allViewers do
        TriggerClientEvent("phone:instagram:joinedLive", allViewers[i], {
            username = username,
            name = account.name,
            avatar = account.profile_image,
            verified = account.verified,
            id = liveId,
            host = hostUsername,
            source = source
        })
    end
    
    callback(true)
end)

RegisterNetEvent("phone:instagram:sendLiveMessage", function(messageData)
    if messageData and messageData.live and LiveData[messageData.live] then
        TriggerClientEvent("phone:instagram:addLiveMessage", -1, messageData)
    end
end)

RegisterNetEvent("phone:instagram:enteredLiveProximity", function(liveUsername)
    local source = source
    local liveData = LiveData[liveUsername]
    local isParticipant = liveData and liveData.participant
    local participantData = {}
    
    if isParticipant then
        participantData = LiveData[liveUsername]
        liveUsername = isParticipant
    end
    
    liveData = LiveData[liveUsername]
    if not liveData then
        return
    end
    
    if table.contains(liveData.nearby, source) then
        return
    end
    
    for i = 1, #liveData.participants do
        if liveData.participants[i].source == source then
            return
        end
    end
    
    liveData.nearby[#liveData.nearby + 1] = source
    
    local shouldHear = table.clone(liveData.viewers)
    if isParticipant then
        shouldHear[#shouldHear + 1] = liveData.host
    end
    
    debugprint("shouldHear (joined)", json.encode(shouldHear, {indent = true}))
    
    TriggerClientEvent("phone:phone:addVoiceTarget", source, shouldHear)
    TriggerClientEvent("phone:instagram:enteredProximity", -1, source, 
        participantData.host or liveData.host)
end)

RegisterNetEvent("phone:instagram:leftLiveProximity", function(liveUsername, isHost)
    local source = source
    local liveData = LiveData[liveUsername]
    local isParticipant = liveData and liveData.participant
    local participantData = {}
    
    if isParticipant then
        participantData = LiveData[liveUsername]
        liveUsername = isParticipant
    end
    
    liveData = LiveData[liveUsername]
    if not liveData then
        return
    end
    
    for i = 1, #liveData.nearby do
        if liveData.nearby[i] == source then
            LiveData[liveUsername].nearby[i] = nil
            break
        end
    end
    
    local shouldHear = table.clone(liveData.viewers)
    if isParticipant or isHost then
        shouldHear[#shouldHear + 1] = liveData.host
    end
    
    debugprint("shouldHear (left)", json.encode(shouldHear, {indent = true}))
    
    TriggerClientEvent("phone:phone:removeVoiceTarget", source, shouldHear)
    TriggerClientEvent("phone:instagram:leftProximity", -1, source,
        participantData.host or liveData.host)
end)

RegisterLegacyCallback("instagram:addToStory", function(source, callback, image, metadata)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback(false)
    end
    
    local storyId = GenerateId("phone_instagram_stories", "id")
    
    MySQL.Async.execute(
        "INSERT INTO phone_instagram_stories (id, username, image, metadata) VALUES (@id, @username, @image, @metadata)",
        {
            ["@id"] = storyId,
            ["@username"] = username,
            ["@image"] = image,
            ["@metadata"] = metadata and json.encode(metadata) or nil
        },
        function(affectedRows)
            callback(affectedRows > 0)
        end
    )
    
    MySQL.Async.fetchAll(
        "SELECT profile_image, verified FROM phone_instagram_accounts WHERE username=@username",
        {["@username"] = username},
        function(accountData)
            TriggerClientEvent("phone:instagram:addStory", -1, {
                username = username,
                avatar = accountData[1].profile_image,
                verified = accountData[1].verified,
                seen = false
            })
            
            Log("InstaPic", source, "info",
                L("BACKEND.LOGS.ADDED_STORY", {username = username}),
                image
            )
        end
    )
end)

RegisterLegacyCallback("instagram:removeFromStory", function(source, callback, storyId)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback(false)
    end
    
    MySQL.Async.execute(
        "DELETE FROM phone_instagram_stories WHERE id=@id AND username=@username",
        {["@id"] = storyId, ["@username"] = username},
        function(affectedRows)
            callback(affectedRows > 0)
        end
    )
end)

RegisterLegacyCallback("instagram:getStories", function(source, callback)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback({})
    end
    
    MySQL.Async.fetchAll([[
        SELECT
            s.username, a.verified, a.profile_image AS avatar,
            (SELECT
                (SELECT COUNT(*) FROM phone_instagram_stories s2
                    WHERE s2.username = s.username AND NOT EXISTS (
                    SELECT TRUE FROM phone_instagram_stories_views v
                    WHERE v.viewer = @loggedInAs AND v.story_id = s2.id
                )
            ) = 0) AS seen
        FROM phone_instagram_stories s
        INNER JOIN phone_instagram_accounts a
        ON a.username = s.username
        WHERE a.private=FALSE OR EXISTS (
            SELECT TRUE FROM phone_instagram_follows f
            WHERE f.followed = s.username AND f.follower = @loggedInAs
        )
        GROUP BY s.username
        ORDER BY s.`timestamp` DESC
    ]], {["@loggedInAs"] = username}, callback)
end)

InstagramBaseCallback("getStory", function(source, phoneNumber, loggedInUsername, targetUsername)
    local stories = MySQL.query.await([[
        SELECT
            s.id, s.image, s.metadata, s.`timestamp`,
            (IF((
                SELECT TRUE FROM phone_instagram_stories_views v
                WHERE v.viewer = ? AND v.story_id = s.id
            ), TRUE, FALSE)) AS seen
        FROM phone_instagram_stories s
        WHERE s.username = ?
        ORDER BY s.timestamp ASC
    ]], {loggedInUsername, targetUsername})
    
    if not stories or #stories == 0 then
        return stories
    end
    
    for i = 1, #stories do
        local story = stories[i]
        
        if story.metadata then
            story.metadata = json.decode(story.metadata)
        end
        
        if loggedInUsername == targetUsername then
            story.views = MySQL.scalar.await(
                "SELECT COUNT(1) FROM phone_instagram_stories_views WHERE story_id = ? AND viewer != ?",
                {story.id, loggedInUsername}
            )
            
            story.viewers = MySQL.query.await([[
                SELECT a.profile_image AS avatar, a.verified
                FROM phone_instagram_stories_views v
                INNER JOIN phone_instagram_accounts a ON a.username = v.viewer
                WHERE v.story_id = ? AND v.viewer != ?
                ORDER BY v.`timestamp` DESC
                LIMIT 3
            ]], {story.id, loggedInUsername})
        end
    end
    
    return stories
end)

RegisterLegacyCallback("instagram:getViewers", function(source, callback, storyId, page)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback(false)
    end
    
    local isOwner = MySQL.Sync.fetchScalar(
        "SELECT TRUE FROM phone_instagram_stories WHERE id = @id AND username = @loggedInAs",
        {["@id"] = storyId, ["@loggedInAs"] = username}
    )
    
    if not isOwner then
        return callback({})
    end
    
    MySQL.Async.fetchAll([[
        SELECT a.profile_image AS avatar, a.verified, a.display_name AS `name`, a.username
        FROM phone_instagram_stories_views v
        INNER JOIN phone_instagram_accounts a ON a.username = v.viewer
        WHERE v.story_id = @id AND v.viewer != @loggedInAs
        ORDER BY v.`timestamp` DESC
        LIMIT @page, @perPage
    ]], {
        ["@id"] = storyId,
        ["@loggedInAs"] = username,
        ["@page"] = (page or 0) * 15,
        ["@perPage"] = 15
    }, callback)
end)

RegisterLegacyCallback("instagram:viewedStory", function(source, callback, storyId)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback(false)
    end
    
    MySQL.Async.execute(
        "INSERT IGNORE INTO phone_instagram_stories_views (story_id, viewer) VALUES (@id, @loggedInAs)",
        {["@id"] = storyId, ["@loggedInAs"] = username},
        function(affectedRows)
            callback(affectedRows > 0)
        end
    )
end)

CreateThread(function()
    while not DatabaseCheckerFinished do
        Wait(500)
    end
    
    while true do
        MySQL.Async.execute(
            "DELETE FROM phone_instagram_stories WHERE `timestamp` < DATE_SUB(NOW(), INTERVAL 24 HOUR)",
            {}
        )
        Wait(3600000)
    end
end)

local NotificationTypes = {
    like_photo = "BACKEND.INSTAGRAM.LIKED_PHOTO",
    like_comment = "BACKEND.INSTAGRAM.LIKED_COMMENT",
    comment = "BACKEND.INSTAGRAM.COMMENTED",
    follow = "BACKEND.INSTAGRAM.NEW_FOLLOWER"
}

function CreateInstagramNotification(targetUsername, fromUsername, notificationType, postId)
    if targetUsername == fromUsername then
        return
    end
    
    local messageKey = NotificationTypes[notificationType]
    if not messageKey then
        return
    end
    
    local content = L(messageKey, {username = fromUsername})
    
    if notificationType == "follow" or notificationType == "like_photo" or notificationType == "like_comment" then
        local existingNotification = MySQL.Sync.fetchScalar(
            "SELECT TRUE FROM phone_instagram_notifications WHERE username=@username AND `from`=@from AND `type`=@type" ..
            (notificationType ~= "follow" and " AND post_id=@post_id" or ""),
            {
                ["@username"] = targetUsername,
                ["@from"] = fromUsername,
                ["@type"] = notificationType,
                ["@post_id"] = postId
            }
        )
        
        if existingNotification then
            return
        end
    end
    
    MySQL.Async.execute(
        "INSERT INTO phone_instagram_notifications (id, username, `from`, `type`, post_id) VALUES (@id, @username, @from, @type, @postId)",
        {
            ["@id"] = GenerateId("phone_instagram_notifications", "id"),
            ["@username"] = targetUsername,
            ["@from"] = fromUsername,
            ["@type"] = notificationType,
            ["@postId"] = postId
        }
    )
    
    local thumbnail = nil
    if notificationType == "like_photo" or notificationType == "comment" then
        MySQL.Async.fetchScalar(
            "SELECT TRIM(BOTH '\"' FROM JSON_EXTRACT(media, '$[0]')) FROM phone_instagram_posts WHERE id=@id",
            {["@id"] = postId}
        )
        thumbnail = thumbnail
    end

    local phoneNumbers = GetLoggedInPhoneNumbers(targetUsername)
    for i = 1, #phoneNumbers do
        SendNotification(phoneNumbers[i], {
            app = "Instagram",
            title = L("APPS.INSTAGRAM.TITLE"),
            content = content,
            thumbnail = thumbnail
        })
    end
end

RegisterLegacyCallback("instagram:getNotifications", function(source, callback, page)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback({
            notifications = {},
            requests = {
                recent = {},
                total = 0
            }
        })
    end
    
    local notifications = MySQL.Sync.fetchAll([[
        SELECT
            (
                SELECT CASE WHEN f.followed IS NULL THEN FALSE ELSE TRUE END
                    FROM phone_instagram_follows f
                    WHERE f.follower=@username AND f.followed=n.`from`
            ) AS isFollowing,
            -- notification data
            n.`from` AS username,
            n.`type`,
            n.`timestamp`,
            -- post photo
            TRIM(BOTH '"' FROM JSON_EXTRACT(p.media, '$[0]')) AS photo,
            p.id AS postId,
            -- comment text
            c.`comment`,
            c.id AS commentId,
            -- account data
            a.profile_image AS avatar,
            a.verified

        FROM phone_instagram_notifications n

        LEFT JOIN phone_instagram_comments c
            ON n.post_id = c.id

        LEFT JOIN phone_instagram_posts p
            ON p.id = (CASE
                WHEN n.`type`="like_photo"
                THEN n.post_id

                WHEN n.`type`="comment"
                THEN c.post_id

                WHEN n.`type`="like_comment"
                THEN c.post_id

                ELSE NULL
                END
            )

        LEFT JOIN phone_instagram_accounts a
            ON a.username=n.`from`

        WHERE n.username=@username

        ORDER BY n.`timestamp` DESC

        LIMIT @page, @perPage
    ]], {
        ["@username"] = username,
        ["@page"] = page * 15,
        ["@perPage"] = 15
    })
    
    if page > 0 then
        return callback({
            notifications = notifications
        })
    end
    
    local recentRequests = MySQL.Sync.fetchAll([[
        SELECT a.username, a.profile_image AS avatar

        FROM phone_instagram_follow_requests r

        INNER JOIN phone_instagram_accounts a
            ON a.username = r.requester

        WHERE r.requestee=@username

        ORDER BY r.`timestamp` DESC

        LIMIT 2
    ]], {
        ["@username"] = username
    })
    
    local totalRequests = MySQL.Sync.fetchScalar(
        "SELECT COUNT(1) FROM phone_instagram_follow_requests WHERE requestee=@username",
        {["@username"] = username}
    )
    
    callback({
        notifications = notifications,
        requests = {
            recent = recentRequests,
            total = totalRequests
        }
    })
end)

RegisterLegacyCallback("instagram:getFollowRequests", function(source, callback, page)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback({})
    end
    
    MySQL.Async.fetchAll([[
        SELECT a.username, a.display_name AS `name`, a.profile_image AS avatar, a.verified
        FROM phone_instagram_follow_requests r

        INNER JOIN phone_instagram_accounts a
            ON a.username = r.requester

        WHERE r.requestee=@loggedInAs

        ORDER BY r.`timestamp` DESC

        LIMIT @page, @perPage
    ]], {
        ["@loggedInAs"] = username,
        ["@page"] = (page or 0) * 15,
        ["@perPage"] = 15
    }, callback)
end)

RegisterLegacyCallback("instagram:handleFollowRequest", function(source, callback, username, accept)
    local loggedInUser = GetLoggedInInstagramUser(source)
    if not loggedInUser then
        return callback(false)
    end
    
    local params = {
        ["@loggedInAs"] = loggedInUser,
        ["@username"] = username
    }
    
    local affectedRows = MySQL.Sync.execute(
        "DELETE FROM phone_instagram_follow_requests WHERE requestee=@loggedInAs AND requester=@username",
        params
    )
    
    if affectedRows == 0 then
        return callback(false)
    end
    
    if not accept then
        return callback(true)
    end
    
    MySQL.Sync.execute(
        "INSERT IGNORE INTO phone_instagram_follows (follower, followed) VALUES (@username, @loggedInAs)",
        params
    )
    
    TriggerClientEvent("phone:instagram:updateProfileData", -1, loggedInUser, "followers", true)
    TriggerClientEvent("phone:instagram:updateProfileData", -1, username, "following", true)
    
    local displayName = MySQL.Sync.fetchScalar(
        "SELECT display_name FROM phone_instagram_accounts WHERE username=@loggedInAs",
        params
    )
    
    local phoneNumbers = GetLoggedInPhoneNumbers(username)
    for i = 1, #phoneNumbers do
        SendNotification(phoneNumbers[i], {
            app = "Instagram",
            title = L("BACKEND.INSTAGRAM.FOLLOW_REQUEST_ACCEPTED_TITLE"),
            content = L("BACKEND.INSTAGRAM.FOLLOW_REQUEST_ACCEPTED_DESCRIPTION", {
                displayName = displayName,
                username = loggedInUser
            })
        })
    end
    
    callback(true)
end)

RegisterLegacyCallback("instagram:search", function(source, callback, searchTerm)
    MySQL.Async.fetchAll([[
        SELECT username, display_name AS name, profile_image AS avatar, verified, private
        FROM phone_instagram_accounts
        WHERE
            username LIKE CONCAT(@search, "%")
            OR
            display_name LIKE CONCAT("%", @search, "%")
    ]], {
        ["@search"] = searchTerm
    }, callback)
end)

RegisterLegacyCallback("instagram:createAccount", function(source, callback, displayName, username, password)
    username = username:lower()
    local phoneNumber = GetEquippedPhoneNumber(source)
    
    if not phoneNumber then
        return callback({
            success = false,
            error = "UNKNOWN"
        })
    end
    
    if not IsUsernameValid(username) then
        return callback({
            success = false,
            error = "USERNAME_NOT_ALLOWED"
        })
    end
    
    debugprint("INSTAGRAM", string.format("%s wants to create an account", phoneNumber))
    
    local existingUser = MySQL.Sync.fetchScalar(
        "SELECT username FROM phone_instagram_accounts WHERE username=@username",
        {["@username"] = username}
    )
    
    if existingUser then
        debugprint("INSTAGRAM", string.format("%s tried to create an account with an existing username", phoneNumber))
        return callback({
            success = false,
            error = "USERNAME_TAKEN"
        })
    end
    
    MySQL.Sync.execute(
        "INSERT INTO phone_instagram_accounts (display_name, username, password, phone_number) VALUES (@displayName, @username, @password, @phonenumber)",
        {
            ["@displayName"] = displayName,
            ["@username"] = username,
            ["@password"] = GetPasswordHash(password),
            ["@phonenumber"] = phoneNumber
        }
    )
    
    debugprint("INSTAGRAM", string.format("%s created an account", phoneNumber))
    
    AddLoggedInAccount(phoneNumber, "Instagram", username)
    
    callback({success = true})
    
    if Config.AutoFollow.Enabled and Config.AutoFollow.InstaPic.Enabled then
        for i = 1, #Config.AutoFollow.InstaPic.Accounts do
            MySQL.update.await(
                "INSERT INTO phone_instagram_follows (followed, follower) VALUES (?, ?)",
                {Config.AutoFollow.InstaPic.Accounts[i], username}
            )
        end
    end
end, {
    preventSpam = true,
    rateLimit = 4
})

InstagramBaseCallback("changePassword", function(source, phoneNumber, username, oldPassword, newPassword)
    if not Config.ChangePassword.InstaPic then
        infoprint("warning", string.format("%s tried to change password on InstaPic, but it's not enabled in the config.", source))
        return false
    end
    
    if oldPassword == newPassword or #newPassword < 3 then
        debugprint("same password / too short")
        return false
    end
    
    if LiveData[username] then
        debugprint("Can't change password when live")
        return false
    end
    
    local storedPassword = MySQL.scalar.await(
        "SELECT password FROM phone_instagram_accounts WHERE username = ?",
        {username}
    )
    
    if not storedPassword or not VerifyPasswordHash(oldPassword, storedPassword) then
        return false
    end
    
    local updated = MySQL.update.await(
        "UPDATE phone_instagram_accounts SET password = ? WHERE username = ?",
        {GetPasswordHash(newPassword), username}
    ) > 0
    
    if not updated then
        return false
    end
    
    NotifyLoggedInUsers(username, {
        title = L("BACKEND.MISC.LOGGED_OUT_PASSWORD.TITLE"),
        content = L("BACKEND.MISC.LOGGED_OUT_PASSWORD.DESCRIPTION")
    }, phoneNumber)
    
    MySQL.update.await(
        "DELETE FROM phone_logged_in_accounts WHERE username = ? AND app = 'Instagram' AND phone_number != ?",
        {username, phoneNumber}
    )
    
    ClearActiveAccountsCache("Instagram", username, phoneNumber)
    
    Log("InstaPic", source, "info",
        L("BACKEND.LOGS.CHANGED_PASSWORD.TITLE"),
        L("BACKEND.LOGS.CHANGED_PASSWORD.DESCRIPTION", {
            number = phoneNumber,
            username = username,
            app = "InstaPic"
        })
    )
    
    TriggerClientEvent("phone:logoutFromApp", -1, {
        username = username,
        app = "instagram",
        reason = "password",
        number = phoneNumber
    })
    
    return true
end, false)

InstagramBaseCallback("deleteAccount", function(source, phoneNumber, username, password)
    if not Config.DeleteAccount.InstaPic then
        infoprint("warning", string.format("%s tried to delete their account on InstaPic, but it's not enabled in the config.", source))
        return false
    end
    
    if LiveData[username] then
        debugprint("Can't delete account when live")
        return false
    end
    
    local storedPassword = MySQL.scalar.await(
        "SELECT password FROM phone_instagram_accounts WHERE username = ?",
        {username}
    )
    
    if not storedPassword or not VerifyPasswordHash(password, storedPassword) then
        return false
    end
    
    local deleted = MySQL.update.await(
        "DELETE FROM phone_instagram_accounts WHERE username = ?",
        {username}
    ) > 0
    
    if not deleted then
        return false
    end
    
    NotifyLoggedInUsers(username, {
        title = L("BACKEND.MISC.DELETED_NOTIFICATION.TITLE"),
        content = L("BACKEND.MISC.DELETED_NOTIFICATION.DESCRIPTION")
    })
    
    MySQL.update.await(
        "DELETE FROM phone_logged_in_accounts WHERE username = ? AND app = 'Instagram'",
        {username}
    )
    
    ClearActiveAccountsCache("Instagram", username)
    
    Log("InstaPic", source, "info",
        L("BACKEND.LOGS.DELETED_ACCOUNT.TITLE"),
        L("BACKEND.LOGS.DELETED_ACCOUNT.DESCRIPTION", {
            number = phoneNumber,
            username = username,
            app = "InstaPic"
        })
    )
    
    TriggerClientEvent("phone:logoutFromApp", -1, {
        username = username,
        app = "instagram",
        reason = "deleted"
    })
    
    return true
end, false)

RegisterLegacyCallback("instagram:logIn", function(source, callback, username, password)
    local phoneNumber = GetEquippedPhoneNumber(source)
    if not phoneNumber then
        return callback({
            success = false,
            error = "UNKNOWN"
        })
    end
    
    debugprint("INSTAGRAM", string.format("%s wants to log in on account %s", phoneNumber, username))
    debugprint("INSTAGRAM", string.format("%s is not logged in, checking if account exists", phoneNumber))
    
    username = username:lower()
    
    MySQL.Async.fetchScalar(
        "SELECT password FROM phone_instagram_accounts WHERE username=@username",
        {["@username"] = username},
        function(storedPassword)
            if not storedPassword then
                debugprint("INSTAGRAM", string.format("%s tried to log in on non-existing account %s", phoneNumber, username))
                return callback({
                    success = false,
                    error = "UNKNOWN_ACCOUNT"
                })
            end
            
            if not VerifyPasswordHash(password, storedPassword) then
                debugprint("INSTAGRAM", string.format("%s tried to log in on account %s with wrong password", phoneNumber, username))
                return callback({
                    success = false,
                    error = "INCORRECT_PASSWORD"
                })
            end
            
            debugprint("INSTAGRAM", string.format("%s logged in on account %s", phoneNumber, username))
            
            AddLoggedInAccount(phoneNumber, "Instagram", username)
            
            MySQL.Async.fetchAll([[
                SELECT
                    display_name AS name, username, profile_image AS avatar, verified
                FROM phone_instagram_accounts
                WHERE username = @username
            ]], {
                ["@username"] = username
            }, function(accountData)
                debugprint("INSTAGRAM", string.format("%s got account data", phoneNumber))
                callback({
                    success = true,
                    account = accountData and accountData[1]
                })
            end)
        end
    )
end)

RegisterLegacyCallback("instagram:isLoggedIn", function(source, callback)
    local phoneNumber = GetEquippedPhoneNumber(source)
    if not phoneNumber then
        return callback(false)
    end
    
    local username = GetLoggedInAccount(phoneNumber, "Instagram")
    if not username then
        return callback(false)
    end
    
    local accountData = MySQL.single.await([[
        SELECT display_name AS `name`, username, profile_image AS avatar, verified
        FROM phone_instagram_accounts
        WHERE username = ?
    ]], {username})
    
    callback(accountData or false)
end)

RegisterLegacyCallback("instagram:signOut", function(source, callback)
    local phoneNumber = GetEquippedPhoneNumber(source)
    if not phoneNumber then
        return callback(false)
    end
    
    local username = GetLoggedInAccount(phoneNumber, "Instagram")
    if not username then
        return callback(false)
    end
    
    RemoveLoggedInAccount(phoneNumber, "Instagram", username)
    callback(true)
end)

RegisterLegacyCallback("instagram:getProfile", function(source, callback, targetUsername)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback(false)
    end
    
    MySQL.Async.fetchAll([[
        SELECT display_name AS name, username, profile_image AS avatar, bio, verified, private, follower_count as followers, following_count as following, post_count as posts,
            (
                IF((SELECT TRUE FROM phone_instagram_follows f WHERE f.followed=@username AND f.follower=@loggedInAs), TRUE, FALSE)
            ) AS isFollowing,
            (
                IF((SELECT TRUE FROM phone_instagram_follow_requests fr WHERE fr.requester=@loggedInAs AND fr.requestee=@username), TRUE, FALSE)
            ) AS requested,

            (SELECT a.story_count > 0) AS hasStory,
            (SELECT a.story_count = (
                SELECT COUNT(*) FROM phone_instagram_stories_views
                WHERE viewer=@loggedInAs
                    AND story_id IN (SELECT id FROM phone_instagram_stories WHERE username=@username)
            )) AS seenStory

        FROM phone_instagram_accounts a

        WHERE a.username=@username
    ]], {
        ["@username"] = targetUsername,
        ["@loggedInAs"] = username
    }, function(result)
        local profile = result[1]
        if profile then
            profile.isLive = LiveData[targetUsername] ~= nil
        end
        callback(profile or false)
    end)
end)

RegisterLegacyCallback("instagram:createPost", function(source, callback, media, caption, location)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback(false)
    end
    
    if ContainsBlacklistedWord(source, "InstaPic", caption) then
        return callback(false)
    end
    
    local postId = GenerateId("phone_instagram_posts", "id")
    
    MySQL.Sync.execute(
        "INSERT INTO phone_instagram_posts (id, username, media, caption, location) VALUES (@id, @username, @media, @caption, @location)",
        {
            ["@id"] = postId,
            ["@username"] = username,
            ["@media"] = media,
            ["@caption"] = caption,
            ["@location"] = location
        }
    )
    
    callback(true)
    
    local postData = {
        username = username,
        media = media,
        caption = caption,
        location = location,
        id = postId
    }
    
    TriggerClientEvent("phone:instagram:newPost", -1, postData)
    TriggerEvent("lb-phone:instapic:newPost", postData)
    
    local mediaArray = json.decode(media)
    local logContent = "**Caption**: " .. (caption or "") .. "\n\n**Photos**:\n"
    
    for i = 1, #mediaArray do
        logContent = logContent .. string.format("[Photo %s](%s)\n", i, mediaArray[i])
    end
    
    logContent = logContent .. "**ID:** " .. postId
    
    Log("InstaPic", source, "info", "New post", logContent)
    TrackSocialMediaPost("instapic", mediaArray)
    
    if Config.Post.InstaPic and INSTAPIC_WEBHOOK and INSTAPIC_WEBHOOK:sub(-14) ~= "/api/webhooks/" then
        local avatar = MySQL.Sync.fetchScalar(
            "SELECT profile_image FROM phone_instagram_accounts WHERE username=@username",
            {["@username"] = username}
        )
        
        PerformHttpRequest(INSTAPIC_WEBHOOK, function() end, "POST", json.encode({
            username = Config.Post.Accounts.InstaPic.Username or "InstaPic",
            avatar_url = Config.Post.Accounts.InstaPic.Avatar or "https://loaf-scripts.com/fivem/lb-phone/icons/InstaPic.png",
            embeds = {{
                title = L("APPS.INSTAGRAM.NEW_POST"),
                description = (caption and #caption > 0) and caption or nil,
                color = 9059001,
                timestamp = GetTimestampISO(),
                author = {
                    name = "@" .. username,
                    icon_url = avatar or "https://cdn.discordapp.com/embed/avatars/5.png"
                },
                image = {
                    url = mediaArray[1]
                },
                footer = {
                    text = "LB Phone",
                    icon_url = "https://docs.lbscripts.com/images/icons/icon.png"
                }
            }}
        }), {
            ["Content-Type"] = "application/json"
        })
    end
end, {
    preventSpam = true,
    rateLimit = 6
})

RegisterLegacyCallback("instagram:deletePost", function(source, callback, postId)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback(false)
    end
    
    local canDelete = IsAdmin(source)
    if not canDelete then
        canDelete = MySQL.Sync.fetchScalar(
            "SELECT TRUE FROM phone_instagram_posts WHERE id=@id AND username=@username",
            {["@id"] = postId, ["@username"] = username}
        )
    end
    
    if not canDelete then
        return callback(false)
    end
    
    local params = {["@id"] = postId}
    
    MySQL.Sync.execute("DELETE FROM phone_instagram_likes WHERE id=@id", params)
    MySQL.Sync.execute("DELETE FROM phone_instagram_notifications WHERE post_id=@id", params)
    MySQL.Sync.execute("DELETE FROM phone_instagram_comments WHERE post_id=@id", params)
    
    local deleted = MySQL.Sync.execute("DELETE FROM phone_instagram_posts WHERE id=@id", params) > 0
    
    if deleted then
        Log("InstaPic", source, "error", "Deleted post", "**ID**: " .. postId)
    end
    
    callback(deleted)
end)

RegisterLegacyCallback("instagram:getPost", function(source, callback, postId)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback(false)
    end
    
    MySQL.Async.fetchAll([[
        SELECT
            p.id, p.media, p.caption, p.username, p.timestamp, p.like_count, p.comment_count, p.location,

            a.verified, a.profile_image AS avatar,

            (IF((
                SELECT TRUE FROM phone_instagram_likes l
                WHERE l.id=p.id AND l.username=@loggedInAs AND l.is_comment=FALSE
            ), TRUE, FALSE)) AS liked

        FROM phone_instagram_posts p

        INNER JOIN phone_instagram_accounts a
            ON p.username = a.username

        WHERE p.id=@id
    ]], {
        ["@id"] = postId,
        ["@loggedInAs"] = username
    }, function(result)
        callback(result and result[1] or false)
    end)
end)

RegisterLegacyCallback("instagram:getPosts", function(source, callback, options, page)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback({})
    end
    
    options = options or {}
    
    local whereClause = ""
    local orderBy = "p.timestamp DESC"
    
    if options.following then
        whereClause = [[
            JOIN phone_instagram_follows f

            WHERE f.follower=@loggedInAs
                AND f.followed=p.username
        ]]
    elseif options.profile then
        whereClause = "WHERE p.username=@username"
    else
        whereClause = [[
            WHERE a.private=FALSE
        ]]
    end
    
    local query = string.format([[
        SELECT
            p.id, p.media, p.caption, p.username, p.timestamp, p.like_count, p.comment_count, p.location,

            a.verified, a.profile_image AS avatar,

            (IF((
                SELECT TRUE FROM phone_instagram_likes l
                WHERE l.id=p.id AND l.username=@loggedInAs AND l.is_comment=FALSE
            ), TRUE, FALSE)) AS liked

        FROM phone_instagram_posts p

        INNER JOIN phone_instagram_accounts a
            ON p.username = a.username

        %s

        ORDER BY %s

        LIMIT @page, @perPage
    ]], whereClause, orderBy)
    
    MySQL.Async.fetchAll(query, {
        ["@page"] = page * 15,
        ["@perPage"] = 15,
        ["@loggedInAs"] = username,
        ["@username"] = options.username
    }, callback)
end)

RegisterLegacyCallback("instagram:getComments", function(source, callback, postId, page)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback({})
    end
    
    MySQL.Async.fetchAll([[
        SELECT
            c.id, c.comment, c.`timestamp`, c.like_count,
            a.username, a.profile_image, a.verified,

            (IF((
                SELECT TRUE FROM phone_instagram_likes l
                WHERE l.id=c.id AND l.username=@loggedInAs AND l.is_comment=TRUE
            ), TRUE, FALSE)) AS liked,

            (IF((
                SELECT TRUE FROM phone_instagram_follows f
                WHERE f.follower=@loggedInAs AND f.followed=a.username
            ), TRUE, FALSE)) AS following

        FROM phone_instagram_comments c

        INNER JOIN phone_instagram_accounts a
            ON c.username = a.username

        WHERE c.post_id=@postId

        ORDER BY following DESC, c.like_count DESC, c.`timestamp` DESC

        LIMIT @page, @perPage
    ]], {
        ["@page"] = page * 20,
        ["@perPage"] = 20,
        ["@postId"] = postId,
        ["@loggedInAs"] = username
    }, callback)
end)

RegisterLegacyCallback("instagram:postComment", function(source, callback, postId, comment)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback(false)
    end
    
    if ContainsBlacklistedWord(source, "InstaPic", comment) then
        return callback(false)
    end
    
    local commentId = GenerateId("phone_instagram_comments", "id")
    
    MySQL.Async.execute(
        "INSERT INTO phone_instagram_comments (id, post_id, username, comment) VALUES (@id, @postId, @username, @comment)",
        {
            ["@id"] = commentId,
            ["@postId"] = postId,
            ["@username"] = username,
            ["@comment"] = comment
        },
        function()
            MySQL.Async.fetchScalar(
                "SELECT username FROM phone_instagram_posts WHERE id=@id",
                {["@id"] = postId},
                function(postOwner)
                    CreateInstagramNotification(postOwner, username, "comment", commentId)
                end
            )
            
            TriggerClientEvent("phone:instagram:updatePostData", -1, postId, "comment_count", true)
            callback(commentId)
        end
    )
end, {
    preventSpam = true,
    rateLimit = 10
})

RegisterLegacyCallback("instagram:updateProfile", function(source, callback, data)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback(false)
    end
    
    local updates = ""
    local name = data.name
    local bio = data.bio
    local avatar = data.avatar
    local private = data.private
    
    if name then
        updates = updates .. "display_name=@displayName,"
    end
    if bio then
        updates = updates .. "bio=@bio,"
    end
    if avatar then
        updates = updates .. "profile_image=@avatar,"
    end
    if type(private) == "boolean" then
        updates = updates .. "private=@private,"
    end
    
    updates = updates:sub(1, -2)
    
    MySQL.Async.execute(
        "UPDATE phone_instagram_accounts SET " .. updates .. " WHERE username=@username",
        {
            ["@displayName"] = name,
            ["@bio"] = bio,
            ["@avatar"] = avatar,
            ["@username"] = username,
            ["@private"] = private
        },
        function()
            callback(true)
        end
    )
end)

RegisterLegacyCallback("instagram:toggleFollow", function(source, callback, targetUsername, shouldFollow)
    local username = GetLoggedInInstagramUser(source)
    if not username or targetUsername == username then
        return callback(not shouldFollow)
    end
    
    local function onComplete(affectedRows)
        if affectedRows == 0 then
            return callback(shouldFollow)
        end
        
        TriggerClientEvent("phone:instagram:updateProfileData", -1, targetUsername, "followers", shouldFollow)
        TriggerClientEvent("phone:instagram:updateProfileData", -1, username, "following", shouldFollow)
        
        callback(shouldFollow)
        
        if shouldFollow then
            CreateInstagramNotification(targetUsername, username, "follow")
        end
    end
    
    local params = {
        ["@username"] = targetUsername,
        ["@loggedInAs"] = username
    }
    
    local isPrivate = MySQL.Sync.fetchScalar(
        "SELECT private FROM phone_instagram_accounts WHERE username=@username",
        params
    )
    
    if isPrivate and shouldFollow then
        MySQL.Async.execute(
            "INSERT IGNORE INTO phone_instagram_follow_requests (requester, requestee) VALUES (@loggedInAs, @username)",
            params,
            function()
                callback(shouldFollow)
            end
        )
        
        local displayName = MySQL.Sync.fetchScalar(
            "SELECT display_name FROM phone_instagram_accounts WHERE username=@loggedInAs",
            params
        )
        
        local phoneNumbers = GetLoggedInPhoneNumbers(targetUsername)
        for i = 1, #phoneNumbers do
            SendNotification(phoneNumbers[i], {
                app = "Instagram",
                title = L("BACKEND.INSTAGRAM.NEW_FOLLOW_REQUEST_TITLE"),
                content = L("BACKEND.INSTAGRAM.NEW_FOLLOW_REQUEST_DESCRIPTION", {
                    displayName = displayName,
                    username = username
                })
            })
        end
        return
    end
    
    if isPrivate and not shouldFollow then
        MySQL.Async.execute(
            "DELETE FROM phone_instagram_follow_requests WHERE requester=@loggedInAs AND requestee=@username",
            params
        )
    end
    
    local query = shouldFollow and 
        "INSERT IGNORE INTO phone_instagram_follows (followed, follower) VALUES (@username, @loggedInAs)" or
        "DELETE FROM phone_instagram_follows WHERE followed=@username AND follower=@loggedInAs"
    
    MySQL.Async.execute(query, params, onComplete)
end, {
    preventSpam = true
})

RegisterLegacyCallback("instagram:toggleLike", function(source, callback, itemId, shouldLike, isComment)
    if not itemId then
        return callback(false)
    end
    
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback(false)
    end
    
    local function onComplete(affectedRows)
        if affectedRows == 0 then
            return callback(shouldLike)
        end
        
        callback(shouldLike)
        
        if isComment then
            TriggerClientEvent("phone:instagram:updateCommentLikes", -1, itemId, shouldLike)
        else
            TriggerClientEvent("phone:instagram:updatePostData", -1, itemId, "like_count", shouldLike)
        end
        
        if shouldLike then
            MySQL.Async.fetchScalar(
                "SELECT username FROM " .. (isComment and "phone_instagram_comments" or "phone_instagram_posts") .. " WHERE id=@postId",
                {["@postId"] = itemId},
                function(owner)
                    if owner then
                        CreateInstagramNotification(owner, username, "like_" .. (isComment and "comment" or "photo"), itemId)
                    end
                end
            )
        end
    end
    
    local query = shouldLike and
        "INSERT IGNORE INTO phone_instagram_likes (id, username, is_comment) VALUES (@postId, @loggedInAs, @isComment)" or
        "DELETE FROM phone_instagram_likes WHERE id=@postId AND username=@loggedInAs AND is_comment=@isComment"
    
    MySQL.Async.execute(query, {
        ["@postId"] = itemId,
        ["@loggedInAs"] = username,
        ["@isComment"] = isComment
    }, onComplete)
end, {
    preventSpam = true
})

RegisterLegacyCallback("instagram:getData", function(source, callback, dataType, options)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback({})
    end
    
    local table = ""
    local column = ""
    local whereClause = ""
    local orderBy = ""
    
    if dataType == "likes" then
        table = "phone_instagram_likes"
        column = "username"
        whereClause = "id=@postId AND is_comment=@isComment"
        orderBy = "a.username"
    elseif dataType == "followers" then
        table = "phone_instagram_follows"
        column = "follower"
        whereClause = "q.followed=@username"
        orderBy = "q.follower"
    elseif dataType == "following" then
        table = "phone_instagram_follows"
        column = "followed"
        whereClause = "q.follower=@username"
        orderBy = "q.followed"
    end
    
    local query = string.format([[
        SELECT
            a.username, a.display_name AS name, a.profile_image AS avatar, a.verified,

            (IF((
                SELECT TRUE FROM phone_instagram_follows f
                WHERE f.followed=a.username AND f.follower=@loggedInAs
            ), TRUE, FALSE)) AS isFollowing

        FROM phone_instagram_accounts a

        INNER JOIN %s q ON q.%s=a.username

        WHERE %s

        ORDER BY %s DESC

        LIMIT @page, @perPage
    ]], table, column, whereClause, orderBy)
    
    MySQL.Async.fetchAll(query, {
        ["@username"] = options.username,
        ["@postId"] = options.postId,
        ["@isComment"] = options.isComment == true,
        ["@loggedInAs"] = username,
        ["@page"] = (options.page or 0) * 20,
        ["@perPage"] = 20
    }, callback)
end)

RegisterLegacyCallback("instagram:getRecentMessages", function(source, callback, page)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback({})
    end
    
    MySQL.Async.fetchAll([[
        SELECT
            m.content, m.attachments, m.sender, f_m.username, m.`timestamp`,

            a.display_name AS `name`, a.profile_image AS avatar, a.verified

        FROM phone_instagram_messages m

        JOIN ((
            SELECT (
                CASE WHEN recipient!=@loggedInAs THEN recipient ELSE sender END
            ) AS username, MAX(`timestamp`) AS `timestamp`

            FROM phone_instagram_messages

            WHERE sender=@loggedInAs OR recipient=@loggedInAs

            GROUP BY username
        ) f_m)
        ON m.`timestamp`=f_m.`timestamp`

        INNER JOIN phone_instagram_accounts a
            ON a.username=f_m.username

        WHERE m.sender=@loggedInAs OR m.recipient=@loggedInAs

        GROUP BY f_m.username

        ORDER BY m.`timestamp` DESC

        LIMIT @page, @perPage
    ]], {
        ["@loggedInAs"] = username,
        ["@page"] = (page or 0) * 15,
        ["@perPage"] = 15
    }, callback)
end)

RegisterLegacyCallback("instagram:getMessages", function(source, callback, targetUsername, page)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback({})
    end
    
    MySQL.Async.fetchAll([[
        SELECT
            sender, recipient, content, attachments, `timestamp`

        FROM phone_instagram_messages

        WHERE (sender=@loggedInAs AND recipient=@username) OR (sender=@username AND recipient=@loggedInAs)

        ORDER BY `timestamp` DESC

        LIMIT @page, @perPage
    ]], {
        ["@loggedInAs"] = username,
        ["@username"] = targetUsername,
        ["@page"] = (page or 0) * 25,
        ["@perPage"] = 25
    }, callback)
end)

RegisterLegacyCallback("instagram:sendMessage", function(source, callback, recipient, messageData)
    local username = GetLoggedInInstagramUser(source)
    if not username then
        return callback(false)
    end
    
    if ContainsBlacklistedWord(source, "InstaPic", messageData) then
        return callback(false)
    end
    
    MySQL.Async.execute(
        "INSERT INTO phone_instagram_messages (id, sender, recipient, content, attachments) VALUES (@id, @sender, @recipient, @content, @attachments)",
        {
            ["@id"] = GenerateId("phone_instagram_messages", "id"),
            ["@sender"] = username,
            ["@recipient"] = recipient,
            ["@content"] = messageData.content,
            ["@attachments"] = messageData.attachments and json.encode(messageData.attachments) or nil
        },
        function(affectedRows)
            if affectedRows == 0 then
                return callback(false)
            end
            
            callback(true)
            
            local phoneNumbers = MySQL.query.await(
                "SELECT phone_number FROM phone_logged_in_accounts WHERE username = ? AND app = 'Instagram' AND `active` = 1",
                {recipient}
            )
            
            if not phoneNumbers or #phoneNumbers == 0 then
                return
            end
            
            MySQL.single(
                "SELECT display_name, username, profile_image FROM phone_instagram_accounts WHERE username = ?",
                {username},
                function(accountData)
                    if not accountData then
                        return
                    end
                    
                    for i = 1, #phoneNumbers do
                        local phoneNumber = phoneNumbers[i].phone_number
                        local targetSource = GetSourceFromNumber(phoneNumber)
                        
                        if targetSource then
                            TriggerClientEvent("phone:instagram:newMessage", targetSource, {
                                sender = username,
                                recipient = recipient,
                                content = messageData.content,
                                attachments = messageData.attachments,
                                timestamp = os.time() * 1000
                            })
                        end
                        
                        local content = messageData.content
                        if string.find(content, "<!REPLIED_STORY-DATA=", nil, true) then
                            content = L("APPS.INSTAGRAM.REPLIED_TO_YOUR_STORY")
                        end
                        
                        SendNotification(phoneNumber, {
                            app = "Instagram",
                            title = accountData.display_name,
                            content = content,
                            thumbnail = messageData.attachments and messageData.attachments[1],
                            avatar = accountData.profile_image,
                            showAvatar = true
                        })
                    end
                end
            )
        end
    )
end, {
    preventSpam = true,
    rateLimit = 15
})
