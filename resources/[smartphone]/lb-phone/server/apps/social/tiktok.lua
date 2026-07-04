local function GetLoggedInTikTokUsername(source)
    local phoneNumber = GetEquippedPhoneNumber(source)
    if not phoneNumber then
        return false
    end
    return GetLoggedInAccount(phoneNumber, "TikTok")
end

local function CreateTikTokCallback(name, callback, fallback)
    BaseCallback("tiktok:" .. name, function(source, phoneNumber, username, ...)
        local loggedUsername = GetLoggedInAccount(phoneNumber, "TikTok")
        if not loggedUsername then
            return fallback
        end
        return callback(source, phoneNumber, loggedUsername, ...)
    end, fallback)
end

local function NotifyAllDevices(username, notification, excludeNumber)
    local phoneNumbers = MySQL.query.await(
        "SELECT phone_number FROM phone_logged_in_accounts WHERE username = ? AND app = 'TikTok' AND `active` = 1",
        {username}
    )
    
    notification.app = "TikTok"
    
    for i = 1, #phoneNumbers do
        local phoneNumber = phoneNumbers[i].phone_number
        if phoneNumber ~= excludeNumber then
            SendNotification(phoneNumber, notification)
        end
    end
end

local function GetProfileData(username, loggedInUsername)
    local fields = "`name`, bio, avatar, username, verified, follower_count, following_count, like_count, twitter, instagram, show_likes"
    local profileData = nil
    
    if loggedInUsername then
        profileData = MySQL.Sync.fetchAll(
            string.format([[
                SELECT %s,
                    (SELECT TRUE FROM phone_tiktok_follows WHERE follower = @username AND followed = @loggedIn) AS isFollowingYou,
                    (SELECT TRUE FROM phone_tiktok_follows WHERE follower = @loggedIn AND followed = @username) AS isFollowing
                FROM phone_tiktok_accounts WHERE username = @username
            ]], fields),
            {
                ["@username"] = username,
                ["@loggedIn"] = loggedInUsername
            }
        )
    else
        profileData = MySQL.Sync.fetchAll(
            string.format("SELECT %s FROM phone_tiktok_accounts WHERE username = @username", fields),
            {["@username"] = username}
        )
    end
    
    if profileData and profileData[1] then
        profileData = profileData[1]
        profileData.isFollowing = profileData.isFollowing == 1
        profileData.isFollowingYou = profileData.isFollowingYou == 1
    end
    
    return profileData
end

local notificationTypes = {
    like = "BACKEND.TIKTOK.LIKE",
    save = "BACKEND.TIKTOK.SAVE",
    comment = "BACKEND.TIKTOK.COMMENT",
    follow = "BACKEND.TIKTOK.FOLLOW",
    like_comment = "BACKEND.TIKTOK.LIKED_COMMENT",
    reply = "BACKEND.TIKTOK.REPLIED_COMMENT",
    message = "BACKEND.TIKTOK.DM"
}

local function CreateNotification(targetUsername, fromUsername, type, videoId, commentId, messageData)
    local notificationKey = notificationTypes[type]
    if not notificationKey or targetUsername == fromUsername then
        return
    end
    
    local fromUserData = GetProfileData(fromUsername)
    if not fromUserData then
        return
    end
    
    if type ~= "message" then
        local params = {targetUsername, fromUsername, type}
        local query = "SELECT 1 FROM phone_tiktok_notifications WHERE username = ? AND `from` = ? AND `type` = ?"
        
        if videoId then
            query = query .. " AND video_id = ?"
            table.insert(params, videoId)
        end
        
        if commentId then
            query = query .. " AND comment_id = ?"
            table.insert(params, commentId)
        end
        
        local exists = MySQL.scalar.await(query, params) == 1
        if exists then
            return
        end
        
        MySQL.insert(
            "INSERT INTO phone_tiktok_notifications (username, `from`, `type`, video_id, comment_id) VALUES (?, ?, ?, ?, ?)",
            {targetUsername, fromUsername, type, videoId, commentId}
        )
    end
    
    local thumbnail = nil
    if videoId then
        thumbnail = MySQL.Sync.fetchScalar(
            "SELECT src FROM phone_tiktok_videos WHERE id = @id",
            {["@id"] = videoId}
        )
    end
    
    local notification = {
        app = "TikTok",
        title = L(notificationKey, {displayName = fromUserData.name}),
        thumbnail = thumbnail
    }
    
    if type == "message" then
        notification.avatar = fromUserData.avatar
        notification.content = messageData.content
        notification.showAvatar = true
    end
    
    local phoneNumbers = MySQL.query.await(
        "SELECT phone_number FROM phone_logged_in_accounts WHERE username = ? AND app = 'TikTok' AND `active` = 1",
        {targetUsername}
    )
    
    for i = 1, #phoneNumbers do
        SendNotification(phoneNumbers[i].phone_number, notification)
    end
end

CreateThread(function()
    while not DatabaseCheckerFinished do
        Wait(500)
    end
    
    while true do
        MySQL.Async.execute("DELETE FROM phone_tiktok_notifications WHERE `timestamp` < DATE_SUB(NOW(), INTERVAL 7 DAY)", {})
        Wait(3600000)
    end
end)

RegisterLegacyCallback("tiktok:getNotifications", function(source, callback, page)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    MySQL.Async.fetchAll(
        [[
            SELECT
                n.`type`, n.`timestamp`, n.video_id AS videoId,
                a.`name`, a.avatar, a.username, a.verified,
                CASE
                    WHEN n.video_id IS NOT NULL THEN
                        v.src
                    ELSE NULL
                END AS videoSrc,
                n.comment_id,
                CASE
                    WHEN n.comment_id IS NOT NULL THEN
                        c.comment
                    ELSE NULL
                END AS commentText,
                CASE
                    WHEN n.`type` = 'follow' THEN
                        CASE
                            WHEN f.follower IS NOT NULL THEN
                                TRUE
                            ELSE FALSE
                        END
                    ELSE NULL
                END AS isFollowing,
                CASE
                    WHEN n.`type` = 'reply' THEN
                    c_original.comment
                    ELSE NULL
                END AS originalText
            FROM
                phone_tiktok_notifications n
                LEFT JOIN phone_tiktok_accounts a ON n.from = a.username
                LEFT JOIN phone_tiktok_videos v ON n.video_id = v.id
                LEFT JOIN phone_tiktok_comments c ON n.comment_id = c.id
                LEFT JOIN phone_tiktok_comments c_original ON c.reply_to = c_original.id
                LEFT JOIN phone_tiktok_follows f ON n.username = f.follower AND n.from = f.followed
            WHERE
                n.username = @username
            ORDER BY
                n.`timestamp` DESC
            LIMIT @page, @perPage
        ]],
        {
            ["@username"] = username,
            ["@page"] = (page or 0) * 15,
            ["@perPage"] = 15
        },
        function(results)
            callback({success = true, data = results})
        end
    )
end)

RegisterLegacyCallback("tiktok:login", function(source, callback, username, password)
    local phoneNumber = GetEquippedPhoneNumber(source)
    if not phoneNumber then
        return callback({success = false, error = "no_number"})
    end
    
    username = username:lower()
    
    MySQL.Async.fetchScalar(
        "SELECT password FROM phone_tiktok_accounts WHERE username = @username",
        {["@username"] = username},
        function(storedPassword)
            if not storedPassword then
                return callback({success = false, error = "invalid_username"})
            end
            
            if not VerifyPasswordHash(password, storedPassword) then
                return callback({success = false, error = "incorrect_password"})
            end
            
            local accountData = GetProfileData(username)
            if not accountData then
                return callback({success = false, error = "invalid_username"})
            end
            
            AddLoggedInAccount(phoneNumber, "TikTok", username)
            callback({success = true, data = accountData})
        end
    )
end)

RegisterLegacyCallback("tiktok:signup", function(source, callback, username, password, displayName)
    local phoneNumber = GetEquippedPhoneNumber(source)
    if not phoneNumber then
        return callback({success = false, error = "UNKNOWN"})
    end
    
    username = username:lower()
    
    if not IsUsernameValid(username) then
        return callback({success = false, error = "USERNAME_NOT_ALLOWED"})
    end
    
    local existingUser = MySQL.Sync.fetchScalar(
        "SELECT TRUE FROM phone_tiktok_accounts WHERE username = @username",
        {["@username"] = username}
    )
    
    if existingUser then
        return callback({success = false, error = "USERNAME_TAKEN"})
    end
    
    MySQL.Sync.execute(
        "INSERT INTO phone_tiktok_accounts (`name`, username, password, phone_number) VALUES (@displayName, @username, @password, @phoneNumber)",
        {
            ["@displayName"] = displayName,
            ["@username"] = username,
            ["@password"] = GetPasswordHash(password),
            ["@phoneNumber"] = phoneNumber
        }
    )
    
    AddLoggedInAccount(phoneNumber, "TikTok", username)
    callback({success = true})
    
    if Config.AutoFollow.Enabled and Config.AutoFollow.Trendy.Enabled then
        for i = 1, #Config.AutoFollow.Trendy.Accounts do
            MySQL.update.await(
                "INSERT INTO phone_tiktok_follows (followed, follower) VALUES (?, ?)",
                {Config.AutoFollow.Trendy.Accounts[i], username}
            )
        end
    end
end, {preventSpam = true, rateLimit = 4})

CreateTikTokCallback("changePassword", function(source, phoneNumber, username, oldPassword, newPassword)
    if not Config.ChangePassword.Trendy then
        infoprint("warning", ("%s tried to change password on Trendy, but it's not enabled in the config."):format(source))
        return false
    end
    
    if oldPassword == newPassword or #newPassword < 3 then
        debugprint("same password / too short")
        return false
    end
    
    local storedPassword = MySQL.scalar.await(
        "SELECT password FROM phone_tiktok_accounts WHERE username = ?",
        {username}
    )
    
    if not storedPassword or not VerifyPasswordHash(oldPassword, storedPassword) then
        return false
    end
    
    local success = MySQL.update.await(
        "UPDATE phone_tiktok_accounts SET password = ? WHERE username = ?",
        {GetPasswordHash(newPassword), username}
    ) > 0
    
    if not success then
        return false
    end
    
    NotifyAllDevices(username, {
        title = L("BACKEND.MISC.LOGGED_OUT_PASSWORD.TITLE"),
        content = L("BACKEND.MISC.LOGGED_OUT_PASSWORD.DESCRIPTION")
    }, phoneNumber)
    
    MySQL.update.await(
        "DELETE FROM phone_logged_in_accounts WHERE username = ? AND app = 'TikTok' AND phone_number != ?",
        {username, phoneNumber}
    )
    
    ClearActiveAccountsCache("TikTok", username, phoneNumber)
    
    Log("Trendy", source, "info", L("BACKEND.LOGS.CHANGED_PASSWORD.TITLE"),
        L("BACKEND.LOGS.CHANGED_PASSWORD.DESCRIPTION", {
            number = phoneNumber,
            username = username,
            app = "Trendy"
        })
    )
    
    TriggerClientEvent("phone:logoutFromApp", -1, {
        username = username,
        app = "tiktok",
        reason = "password",
        number = phoneNumber
    })
    
    return true
end, false)

CreateTikTokCallback("deleteAccount", function(source, phoneNumber, username, password)
    if not Config.DeleteAccount.Trendy then
        infoprint("warning", ("%s tried to delete their account on Trendy, but it's not enabled in the config."):format(source))
        return false
    end
    
    local storedPassword = MySQL.scalar.await(
        "SELECT password FROM phone_tiktok_accounts WHERE username = ?",
        {username}
    )
    
    if not storedPassword or not VerifyPasswordHash(password, storedPassword) then
        return false
    end
    
    local success = MySQL.update.await(
        "DELETE FROM phone_tiktok_accounts WHERE username = ?",
        {username}
    ) > 0
    
    if not success then
        return false
    end
    
    NotifyAllDevices(username, {
        title = L("BACKEND.MISC.DELETED_NOTIFICATION.TITLE"),
        content = L("BACKEND.MISC.DELETED_NOTIFICATION.DESCRIPTION")
    })
    
    MySQL.update.await(
        "DELETE FROM phone_logged_in_accounts WHERE username = ? AND app = 'TikTok'",
        {username}
    )
    
    ClearActiveAccountsCache("TikTok", username)
    
    Log("Trendy", source, "info", L("BACKEND.LOGS.DELETED_ACCOUNT.TITLE"),
        L("BACKEND.LOGS.DELETED_ACCOUNT.DESCRIPTION", {
            number = phoneNumber,
            username = username,
            app = "Trendy"
        })
    )
    
    TriggerClientEvent("phone:logoutFromApp", -1, {
        username = username,
        app = "tiktok",
        reason = "deleted"
    })
    
    return true
end, false)

RegisterLegacyCallback("tiktok:logout", function(source, callback)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback(false)
    end
    
    local phoneNumber = GetEquippedPhoneNumber(source)
    if not phoneNumber then
        return callback(false)
    end
    
    RemoveLoggedInAccount(phoneNumber, "TikTok", username)
    callback(true)
end)

RegisterLegacyCallback("tiktok:isLoggedIn", function(source, callback)
    local username = GetLoggedInTikTokUsername(source)
    local accountData = username and GetProfileData(username) or false
    callback(accountData)
end)

RegisterLegacyCallback("tiktok:getProfile", function(source, callback, targetUsername)
    callback(GetProfileData(targetUsername, GetLoggedInTikTokUsername(source)))
end)

RegisterLegacyCallback("tiktok:updateProfile", function(source, callback, profileData)
    local phoneNumber = GetEquippedPhoneNumber(source)
    if not phoneNumber then
        return callback({success = false, error = "no_number"})
    end
    
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    local name = profileData.name
    local bio = profileData.bio
    local avatar = profileData.avatar
    local twitter = profileData.twitter
    local instagram = profileData.instagram
    local showLikes = profileData.show_likes
    
    if #name > 30 then
        return callback({success = false, error = "display_name_too_long"})
    end
    
    if bio and #bio > 150 then
        return callback({success = false, error = "bio_too_long"})
    end
    
    if twitter then
        local hasTwitter = MySQL.Sync.fetchScalar(
            "SELECT TRUE FROM phone_logged_in_accounts WHERE phone_number = @phoneNumber and app = @app and username = @username",
            {
                ["@phoneNumber"] = phoneNumber,
                ["@app"] = "Twitter",
                ["@username"] = twitter
            }
        )
        
        if not hasTwitter then
            return callback({success = false, error = "invalid_twitter"})
        end
    end
    
    if instagram then
        local hasInstagram = MySQL.Sync.fetchScalar(
            "SELECT TRUE FROM phone_logged_in_accounts WHERE phone_number = @phoneNumber and app = @app and username = @username",
            {
                ["@phoneNumber"] = phoneNumber,
                ["@app"] = "Instagram",
                ["@username"] = instagram
            }
        )
        
        if not hasInstagram then
            return callback({success = false, error = "invalid_instagram"})
        end
    end
    
    MySQL.Async.execute(
        "UPDATE phone_tiktok_accounts SET `name` = @displayName, bio = @bio, avatar = @avatar, twitter = @twitter, instagram = @instagram, `show_likes` = @showLikes WHERE username = @username",
        {
            ["@displayName"] = name,
            ["@bio"] = bio,
            ["@avatar"] = avatar,
            ["@twitter"] = twitter,
            ["@instagram"] = instagram,
            ["@showLikes"] = showLikes == true,
            ["@username"] = username
        },
        function()
            callback({success = true})
        end
    )
end)

RegisterLegacyCallback("tiktok:searchAccounts", function(source, callback, query, page)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback(false)
    end
    
    MySQL.Async.fetchAll(
        [[
            SELECT `name`, username, avatar, verified, follower_count, video_count,
                (SELECT TRUE FROM phone_tiktok_follows WHERE follower = @username AND followed = a.username) AS isFollowing
            FROM phone_tiktok_accounts a
            WHERE username LIKE @query OR `name` LIKE @query
            ORDER BY username
            LIMIT @page, @perPage
        ]],
        {
            ["@query"] = "%" .. query .. "%",
            ["@username"] = username,
            ["@page"] = (page or 0) * 10,
            ["@perPage"] = 10
        },
        callback
    )
end)

RegisterLegacyCallback("tiktok:toggleFollow", function(source, callback, targetUsername, follow)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    if targetUsername == username then
        return callback({success = false, error = "cannot_follow_self"})
    end
    
    local targetExists = GetProfileData(targetUsername)
    if not targetExists then
        return callback({success = false, error = "invalid_username"})
    end
    
    callback({success = true})
    
    local query = follow == true and
        "INSERT IGNORE INTO phone_tiktok_follows (follower, followed) VALUES (@follower, @followed)" or
        "DELETE FROM phone_tiktok_follows WHERE follower = @follower AND followed = @followed"
    
    MySQL.Async.execute(
        query,
        {
            ["@follower"] = username,
            ["@followed"] = targetUsername
        },
        function(affectedRows)
            if affectedRows == 0 then
                return
            end
            
            local action = follow == true and "add" or "remove"
            
            TriggerClientEvent("phone:tiktok:updateFollowers", -1, targetUsername, action)
            TriggerClientEvent("phone:tiktok:updateFollowing", -1, username, action)
            
            if follow == true then
                CreateNotification(targetUsername, username, "follow")
            end
        end
    )
end, {preventSpam = true})

RegisterLegacyCallback("tiktok:getFollowing", function(source, callback, targetUsername, page)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({})
    end
    
    MySQL.Async.fetchAll(
        [[
            SELECT
                a.username, a.`name`, a.avatar, a.verified,
                    (SELECT TRUE FROM phone_tiktok_follows WHERE follower = a.username AND followed = @loggedIn) AS isFollowingYou,
                    (SELECT TRUE FROM phone_tiktok_follows WHERE follower = @loggedIn AND followed = a.username) AS isFollowing
            FROM phone_tiktok_follows f
            INNER JOIN phone_tiktok_accounts a ON a.username = f.followed
            WHERE f.follower = @username
            ORDER BY a.username
            LIMIT @page, @perPage
        ]],
        {
            ["@username"] = targetUsername,
            ["@loggedIn"] = username,
            ["@page"] = (page or 0) * 15,
            ["@perPage"] = 15
        },
        callback
    )
end)

RegisterLegacyCallback("tiktok:getFollowers", function(source, callback, targetUsername, page)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({})
    end
    
    MySQL.Async.fetchAll(
        [[
            SELECT
                a.username, a.`name`, a.avatar, a.verified,
                    (SELECT TRUE FROM phone_tiktok_follows WHERE follower = @username AND followed = @loggedIn) AS isFollowingYou,
                    (SELECT TRUE FROM phone_tiktok_follows WHERE follower = @loggedIn AND followed = @username) AS isFollowing
            FROM phone_tiktok_follows f
            INNER JOIN phone_tiktok_accounts a ON a.username = f.follower
            WHERE f.followed = @username
            ORDER BY a.username
            LIMIT @page, @perPage
        ]],
        {
            ["@username"] = targetUsername,
            ["@loggedIn"] = username,
            ["@page"] = (page or 0) * 15,
            ["@perPage"] = 15
        },
        callback
    )
end)

RegisterLegacyCallback("tiktok:uploadVideo", function(source, callback, videoData)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    if ContainsBlacklistedWord(source, "Trendy", videoData.caption) then
        return callback(false)
    end
    
    if not videoData.src or type(videoData.src) ~= "string" or #videoData.src == 0 then
        return callback({success = false, error = "invalid_src"})
    end
    
    if not videoData.caption or type(videoData.caption) ~= "string" or #videoData.caption == 0 then
        return callback({success = false, error = "invalid_caption"})
    end
    
    local videoId = GenerateId("phone_tiktok_videos", "id")
    
    MySQL.Async.execute(
        "INSERT INTO phone_tiktok_videos (id, username, src, caption, metadata, music) VALUES (@id, @username, @src, @caption, @metadata, @music)",
        {
            ["@id"] = videoId,
            ["@username"] = username,
            ["@src"] = videoData.src,
            ["@caption"] = videoData.caption,
            ["@metadata"] = videoData.metadata,
            ["@music"] = videoData.music
        },
        function()
            callback({success = true, id = videoId})
            
            local postData = {
                username = username,
                caption = videoData.caption,
                videoUrl = videoData.src,
                id = videoId
            }
            
            TriggerClientEvent("phone:tiktok:newVideo", -1, postData)
            TriggerEvent("lb-phone:trendy:newPost", postData)
            TrackSocialMediaPost("trendy", {videoData.src})
            
            Log("Trendy", source, "success", L("BACKEND.LOGS.TRENDY_UPLOAD_TITLE"),
                L("BACKEND.LOGS.TRENDY_UPLOAD_DESCRIPTION", {
                    username = username,
                    caption = videoData.caption,
                    id = videoId
                })
            )
        end
    )
end, {preventSpam = true, rateLimit = 6})

RegisterLegacyCallback("tiktok:deleteVideo", function(source, callback, videoId)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    local query = "DELETE FROM phone_tiktok_videos WHERE id = @id"
    if not IsAdmin(source) then
        query = query .. " AND username = @username"
    end
    
    MySQL.Async.execute(
        query,
        {
            ["@id"] = videoId,
            ["@username"] = username
        },
        function(affectedRows)
            callback({success = affectedRows > 0})
            
            if affectedRows > 0 then
                Log("Trendy", source, "error", L("BACKEND.LOGS.TRENDY_DELETE_TITLE"),
                    L("BACKEND.LOGS.TRENDY_DELETE_DESCRIPTION", {
                        username = username,
                        id = videoId
                    })
                )
            end
        end
    )
end)

RegisterLegacyCallback("tiktok:togglePinnedVideo", function(source, callback, videoId, pinned)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    if pinned then
        local pinnedCount = MySQL.Sync.fetchScalar(
            "SELECT COUNT(*) FROM phone_tiktok_pinned_videos WHERE username = @username",
            {["@username"] = username}
        )
        
        if pinnedCount >= 3 and pinned then
            return callback({success = false, error = "max_pinned"})
        end
    end
    
    local query = pinned and
        "INSERT INTO phone_tiktok_pinned_videos (username, video_id) VALUES (@username, @videoId)" or
        "DELETE FROM phone_tiktok_pinned_videos WHERE username = @username AND video_id = @videoId"
    
    MySQL.Async.execute(
        query,
        {
            ["@videoId"] = videoId,
            ["@username"] = username
        },
        function(affectedRows)
            callback({success = affectedRows > 0})
        end
    )
end)

local baseVideoQuery = [[
    SELECT
        v.id, v.src, v.caption, v.`timestamp`,
        p.video_id IS NOT NULL AS pinned,

        v.likes, v.comments, v.views, v.saves,
        (SELECT TRUE FROM phone_tiktok_likes WHERE username = @loggedIn AND video_id = v.id) AS liked,
        (SELECT TRUE FROM phone_tiktok_saves WHERE username = @loggedIn AND video_id = v.id) AS saved,
        w.video_id IS NOT NULL AS viewed,

        v.metadata, v.music,

        a.username, a.`name`, a.avatar, a.verified,
        (SELECT TRUE FROM phone_tiktok_follows WHERE follower = @username AND followed = a.username) AS following

    FROM phone_tiktok_videos v
    INNER JOIN phone_tiktok_accounts a ON a.username = v.username
    LEFT JOIN phone_tiktok_views w ON v.id = w.video_id AND w.username = @loggedIn
    LEFT JOIN phone_tiktok_pinned_videos p ON p.video_id = v.id AND p.username = @loggedIn
]]

RegisterLegacyCallback("tiktok:getVideo", function(source, callback, videoId)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    MySQL.Async.fetchAll(
        baseVideoQuery .. [[
            WHERE v.id = @id
        ]],
        {
            ["@id"] = videoId,
            ["@loggedIn"] = username,
            ["@username"] = username
        },
        function(results)
            if #results == 0 then
                return callback({success = false, error = "invalid_id"})
            end
            
            callback({success = true, video = results[1]})
        end
    )
end)

RegisterLegacyCallback("tiktok:getVideos", function(source, callback, filters, page)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({})
    end
    
    local query = nil
    local perPage = nil
    
    if filters.full then
        if filters.type == "recent" then
            if filters.id then
                if filters.username then
                    query = baseVideoQuery .. string.format([[
                        WHERE v.username = @username AND v.`timestamp` %s (SELECT `timestamp` FROM phone_tiktok_videos WHERE id = @id)
                        ORDER BY (w.username IS NOT NULL), v.timestamp DESC
                        LIMIT @page, @perPage
                    ]], filters.backwards and ">" or "<")
                else
                    query = baseVideoQuery .. string.format([[
                        WHERE v.username != @loggedIn AND v.`timestamp` %s (SELECT `timestamp` FROM phone_tiktok_videos WHERE id = @id)
                        ORDER BY (w.username IS NOT NULL), v.timestamp DESC
                        LIMIT @page, @perPage
                    ]], filters.backwards and ">" or "<")
                end
            else
                query = baseVideoQuery .. [[
                    WHERE v.username != @loggedIn
                    ORDER BY (w.username IS NOT NULL), v.timestamp DESC
                    LIMIT @page, @perPage
                ]]
            end
        elseif filters.type == "following" then
            query = baseVideoQuery .. [[
                INNER JOIN phone_tiktok_follows f ON f.followed = v.username
                WHERE f.follower = @loggedIn
                ORDER BY (w.username IS NOT NULL), v.timestamp DESC
                LIMIT @page, @perPage
            ]]
        end
        perPage = 5
    else
        if filters.type == "recent" then
            if filters.username then
                if page == 0 then
                    query = [[
                        SELECT
                            v.id, v.src, v.views,
                            p.video_id IS NOT NULL AS pinned
                        FROM phone_tiktok_videos v
                        LEFT JOIN phone_tiktok_pinned_videos p ON p.video_id = v.id AND p.username = @username
                        WHERE v.username = @username
                        ORDER BY (p.video_id IS NOT NULL) DESC, v.`timestamp` DESC
                        LIMIT @page, @perPage
                    ]]
                else
                    query = [[
                        SELECT id, src, views
                        FROM phone_tiktok_videos
                        WHERE username = @username
                        ORDER BY `timestamp` DESC
                        LIMIT @page, @perPage
                    ]]
                end
            end
        elseif filters.type == "liked" then
            query = [[
                SELECT v.id, v.src, v.views
                FROM phone_tiktok_videos v
                INNER JOIN phone_tiktok_likes l ON l.video_id = v.id
                WHERE l.username = @username
                ORDER BY v.`timestamp` DESC
                LIMIT @page, @perPage
            ]]
        elseif filters.type == "saved" then
            if username ~= filters.username then
                debugprint("wrong account", username, #username, filters.username, #filters.username)
                return callback({})
            end
            
            query = [[
                SELECT v.id, v.src, v.views
                FROM phone_tiktok_videos v
                INNER JOIN phone_tiktok_saves s ON s.video_id = v.id
                WHERE s.username = @username
                ORDER BY v.`timestamp` DESC
                LIMIT @page, @perPage
            ]]
        end
        perPage = 15
    end
    
    if not query then
        return callback({})
    end
    
    MySQL.Async.fetchAll(
        query,
        {
            ["@username"] = filters.username,
            ["@loggedIn"] = username,
            ["@id"] = filters.id,
            ["@page"] = (page or 0) * perPage,
            ["@perPage"] = perPage
        },
        callback
    )
end)

RegisterNetEvent("phone:tiktok:setViewed", function(videoId)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return
    end
    
    MySQL.Async.execute(
        "INSERT IGNORE INTO phone_tiktok_views (username, video_id) VALUES (@username, @videoId)",
        {
            ["@username"] = username,
            ["@videoId"] = videoId
        }
    )
end)

RegisterLegacyCallback("tiktok:toggleVideoAction", function(source, callback, action, videoId, state)
    if action ~= "like" and action ~= "save" then
        return callback({success = false, error = "invalid_action"})
    end
    
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    local videoOwner = MySQL.Sync.fetchScalar(
        "SELECT username FROM phone_tiktok_videos WHERE id = @id",
        {["@id"] = videoId}
    )
    
    if not videoOwner then
        return callback({success = false, error = "invalid_id"})
    end
    
    callback({success = true})
    
    local tableName = action == "like" and "likes" or "saves"
    local query = state == true and
        string.format("INSERT IGNORE INTO phone_tiktok_%s (username, video_id) VALUES (@username, @videoId)", tableName) or
        string.format("DELETE FROM phone_tiktok_%s WHERE username = @username AND video_id = @videoId", tableName)
    
    MySQL.Async.execute(
        query,
        {
            ["@username"] = username,
            ["@videoId"] = videoId
        },
        function(affectedRows)
            if affectedRows == 0 then
                return
            end
            
            local updateAction = state == true and "add" or "remove"
            TriggerClientEvent("phone:tiktok:updateVideoStats", -1, action, videoId, updateAction)
            
            if state then
                CreateNotification(videoOwner, username, action, videoId)
            end
        end
    )
end, {preventSpam = true, rateLimit = 30})

RegisterLegacyCallback("tiktok:postComment", function(source, callback, videoId, replyTo, comment)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    if not comment or #comment == 0 or #comment > 500 then
        return callback({success = false, error = "invalid_comment"})
    end
    
    if ContainsBlacklistedWord(source, "Trendy", comment) then
        return callback(false)
    end
    
    local videoOwner = MySQL.Sync.fetchScalar(
        "SELECT username FROM phone_tiktok_videos WHERE id = @id",
        {["@id"] = videoId}
    )
    
    if not videoOwner then
        return callback({success = false, error = "invalid_id"})
    end
    
    local replyOwner = not replyTo or MySQL.Sync.fetchScalar(
        "SELECT username FROM phone_tiktok_comments WHERE id = @id",
        {["@id"] = replyTo}
    )
    
    if not replyOwner then
        return callback({success = false, error = "invalid_reply_to"})
    end
    
    local commentId = GenerateId("phone_tiktok_comments", "id")
    
    MySQL.Async.execute(
        "INSERT INTO phone_tiktok_comments (id, reply_to, video_id, username, comment) VALUES (@id, @replyTo, @videoId, @loggedIn, @comment)",
        {
            ["@id"] = commentId,
            ["@replyTo"] = replyTo,
            ["@videoId"] = videoId,
            ["@loggedIn"] = username,
            ["@comment"] = comment
        },
        function(affectedRows)
            if affectedRows == 0 then
                return callback({success = false, error = "failed_insert"})
            end
            
            TriggerClientEvent("phone:tiktok:updateVideoStats", -1, "comment", videoId, "add")
            
            if replyTo then
                MySQL.Async.execute(
                    "UPDATE phone_tiktok_comments SET replies = replies + 1 WHERE id = @id",
                    {["@id"] = replyTo}
                )
                
                TriggerClientEvent("phone:tiktok:updateCommentStats", -1, "reply", replyTo, "add")
                CreateNotification(replyOwner, username, "reply", videoId, commentId)
            end
            
            callback({success = true, id = commentId})
            CreateNotification(videoOwner, username, "comment", videoId, commentId)
        end
    )
end, {preventSpam = true, rateLimit = 10})

RegisterLegacyCallback("tiktok:deleteComment", function(source, callback, commentId, videoId)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    local whereClause = ""
    if not IsAdmin(source) then
        whereClause = " AND username = @username"
    end
    
    local repliesCount = 0
    local replyTo = MySQL.Sync.fetchScalar(
        "SELECT reply_to FROM phone_tiktok_comments WHERE id = @id" .. whereClause,
        {
            ["@id"] = commentId,
            ["@username"] = username
        }
    )
    
    if replyTo then
        MySQL.Async.execute(
            "UPDATE phone_tiktok_comments SET replies = replies - 1 WHERE id = @id",
            {["@id"] = replyTo}
        )
        
        TriggerClientEvent("phone:tiktok:updateCommentStats", -1, "reply", replyTo, "remove")
    else
        repliesCount = MySQL.Sync.fetchScalar(
            "SELECT COUNT(*) FROM phone_tiktok_comments WHERE reply_to = @id",
            {["@id"] = commentId}
        )
    end
    
    MySQL.Async.execute(
        "DELETE FROM phone_tiktok_comments WHERE id = @id" .. whereClause,
        {
            ["@id"] = commentId,
            ["@username"] = username
        },
        function(affectedRows)
            if affectedRows > 0 then
                callback({success = true})
                TriggerClientEvent("phone:tiktok:updateVideoStats", -1, "comment", videoId, "remove", repliesCount + 1)
            else
                callback({success = false, error = "failed_delete"})
            end
        end
    )
end)

RegisterLegacyCallback("tiktok:setPinnedComment", function(source, callback, commentId, videoId)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    local ownsVideo = MySQL.Sync.fetchScalar(
        "SELECT TRUE FROM phone_tiktok_videos WHERE id = @id AND username = @username",
        {
            ["@id"] = videoId,
            ["@username"] = username
        }
    )
    
    if not ownsVideo then
        return callback({success = false, error = "invalid_id"})
    end
    
    if commentId ~= nil then
        local ownsComment = MySQL.Sync.fetchScalar(
            "SELECT TRUE FROM phone_tiktok_comments WHERE id = @id AND username = @username",
            {
                ["@id"] = commentId,
                ["@username"] = username
            }
        )
        
        if not ownsComment then
            return callback({success = false, error = "invalid_comment"})
        end
    end
    
    MySQL.Async.execute(
        "UPDATE phone_tiktok_videos SET pinned_comment = @commentId WHERE id = @id",
        {
            ["@commentId"] = commentId,
            ["@id"] = videoId
        },
        function(affectedRows)
            if affectedRows > 0 then
                callback({success = true})
            else
                callback({success = false, error = "failed_update"})
            end
        end
    )
end)

RegisterLegacyCallback("tiktok:getComments", function(source, callback, videoId, replyTo, creator, page)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    local query = [[
        SELECT
            a.username, a.`name`, a.avatar, a.verified,
            c.id, c.comment, c.likes, c.replies AS reply_count, c.`timestamp`,
            (SELECT TRUE FROM phone_tiktok_comments_likes WHERE username = @loggedIn AND comment_id = c.id) AS liked,
            (SELECT TRUE FROM phone_tiktok_comments_likes WHERE username = @creator AND comment_id = c.id) AS creator_liked

        FROM phone_tiktok_comments c
        INNER JOIN phone_tiktok_accounts a ON a.username = c.username

        WHERE c.video_id = @videoId
    ]]
    
    if replyTo then
        query = query .. " AND c.reply_to = @replyTo"
    else
        query = query .. " AND c.reply_to IS NULL"
    end
    
    query = query .. " ORDER BY c.`timestamp` DESC LIMIT @page, @perPage"
    
    MySQL.Async.fetchAll(
        query,
        {
            ["@loggedIn"] = username,
            ["@creator"] = creator,
            ["@videoId"] = videoId,
            ["@replyTo"] = replyTo,
            ["@page"] = (page or 0) * 15,
            ["@perPage"] = 15
        },
        function(results)
            callback({success = true, comments = results})
        end
    )
end)

RegisterLegacyCallback("tiktok:toggleLikeComment", function(source, callback, commentId, liked)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    if not commentId or liked == nil then
        return callback({success = false, error = "invalid_data"})
    end
    
    local commentData = MySQL.Sync.fetchAll(
        "SELECT username, video_id FROM phone_tiktok_comments WHERE id = @id",
        {["@id"] = commentId}
    )[1]
    
    if not commentData then
        return callback({success = false, error = "invalid_id"})
    end
    
    local query = liked == true and
        "INSERT IGNORE INTO phone_tiktok_comments_likes (username, comment_id) VALUES (@username, @commentId)" or
        "DELETE FROM phone_tiktok_comments_likes WHERE username = @username AND comment_id = @commentId"
    
    MySQL.Async.execute(
        query,
        {
            ["@username"] = username,
            ["@commentId"] = commentId
        },
        function(affectedRows)
            callback({success = true})
            
            if affectedRows == 0 then
                return debugprint("Failed to toggle like comment, no rows changed")
            end
            
            local action = liked == true and "add" or "remove"
            TriggerClientEvent("phone:tiktok:updateCommentStats", -1, "like", commentId, action)
            
            if liked then
                CreateNotification(commentData.username, username, "like_comment", commentData.video_id, commentId)
            end
        end
    )
end, {preventSpam = true})

RegisterLegacyCallback("tiktok:getRecentMessages", function(source, callback)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    MySQL.Async.fetchAll(
        [[
            SELECT
                id, last_message, `timestamp`,
                a.username, a.`name`, a.avatar, a.verified, a.follower_count, a.following_count,
                (SELECT COALESCE(amount, 0) FROM phone_tiktok_unread_messages WHERE channel_id = id AND username = @loggedIn) AS unread_messages

            FROM phone_tiktok_channels
            INNNER JOIN phone_tiktok_accounts a ON a.username = IF(member_1 = @loggedIn, member_2, member_1)
            WHERE member_1 = @loggedIn OR member_2 = @loggedIn ORDER BY `timestamp` DESC
        ]],
        {["@loggedIn"] = username},
        function(results)
            callback({success = true, channels = results})
        end
    )
end)

RegisterLegacyCallback("tiktok:getMessages", function(source, callback, channelId, page)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    local hasAccess = MySQL.Sync.fetchScalar(
        "SELECT TRUE FROM phone_tiktok_channels WHERE id = @id AND (member_1 = @loggedIn OR member_2 = @loggedIn)",
        {
            ["@id"] = channelId,
            ["@loggedIn"] = username
        }
    )
    
    if not hasAccess then
        return callback({success = false, error = "invalid_id"})
    end
    
    MySQL.Async.fetchAll(
        "SELECT id, sender, content, `timestamp` FROM phone_tiktok_messages WHERE channel_id = @channelId ORDER BY `timestamp` DESC LIMIT @page, @perPage",
        {
            ["@channelId"] = channelId,
            ["@page"] = (page or 0) * 25,
            ["@perPage"] = 25
        },
        function(results)
            callback({success = true, messages = results})
        end
    )
end)

RegisterLegacyCallback("tiktok:getUnreadMessages", function(source, callback)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    MySQL.Async.fetchScalar(
        "SELECT COUNT(*) FROM phone_tiktok_unread_messages WHERE username = @username AND amount > 0",
        {["@username"] = username},
        function(unreadCount)
            callback({success = true, unread = unreadCount})
        end
    )
end)

RegisterNetEvent("phone:tiktok:clearUnreadMessages", function(channelId)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return
    end
    
    MySQL.Async.execute(
        "UPDATE phone_tiktok_unread_messages SET amount = 0 WHERE username = @username AND channel_id = @channelId",
        {
            ["@username"] = username,
            ["@channelId"] = channelId
        }
    )
end)

RegisterLegacyCallback("tiktok:sendMessage", function(source, callback, messageData)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    if ContainsBlacklistedWord(source, "Trendy", messageData.content) then
        return callback(false)
    end
    
    local channelId = messageData.id
    local content = messageData.content
    local targetUsername = messageData.username
    
    if not channelId then
        if not targetUsername then
            return callback({success = false, error = "invalid_id"})
        end
        
        channelId = MySQL.Sync.fetchScalar(
            "SELECT id FROM phone_tiktok_channels WHERE (member_1 = @loggedIn AND member_2 = @username) OR (member_1 = @username AND member_2 = @loggedIn)",
            {
                ["@loggedIn"] = username,
                ["@username"] = targetUsername
            }
        )
        
        if not channelId then
            channelId = GenerateId("phone_tiktok_channels", "id")
            local success = MySQL.Sync.execute(
                "INSERT IGNORE INTO phone_tiktok_channels (id, last_message, member_1, member_2) VALUES (@id, @message, @member_1, @member_2)",
                {
                    ["@id"] = channelId,
                    ["@message"] = content,
                    ["@member_1"] = username,
                    ["@member_2"] = targetUsername
                }
            ) > 0
            
            if not success then
                return callback({success = false, error = "failed_create_channel"})
            end
        end
    end
    
    local messageId = GenerateId("phone_tiktok_messages", "id")
    
    MySQL.Async.execute(
        "INSERT INTO phone_tiktok_messages (id, channel_id, sender, content) VALUES (@messageId, @channelId, @sender, @content)",
        {
            ["@messageId"] = messageId,
            ["@channelId"] = channelId,
            ["@sender"] = username,
            ["@content"] = content
        },
        function(affectedRows)
            callback({
                success = affectedRows > 0,
                id = messageId,
                channelId = channelId,
                error = "failed_insert"
            })
            
            if affectedRows > 0 then
                MySQL.Async.execute(
                    [[
                        INSERT INTO phone_tiktok_unread_messages
                            (username, channel_id, amount)
                        VALUES
                            (@username, @channelId, 1)
                        ON DUPLICATE KEY UPDATE
                            amount = amount + 1
                    ]],
                    {
                        ["@username"] = targetUsername,
                        ["@channelId"] = channelId
                    }
                )
                
                local activeAccounts = GetActiveAccounts("TikTok")
                for phoneNumber, accountUsername in pairs(activeAccounts) do
                    if accountUsername == targetUsername then
                        local targetSource = GetSourceFromNumber(phoneNumber)
                        if targetSource then
                            TriggerClientEvent("phone:tiktok:receivedMessage", targetSource, {
                                id = messageId,
                                channelId = channelId,
                                sender = username,
                                content = content
                            })
                        end
                    end
                end
                
                CreateNotification(targetUsername, username, "message", nil, nil, {content = content})
            end
        end
    )
end, {preventSpam = true})

RegisterLegacyCallback("tiktok:getChannelId", function(source, callback, targetUsername)
    local username = GetLoggedInTikTokUsername(source)
    if not username then
        return callback({success = false, error = "not_logged_in"})
    end
    
    local channelId = MySQL.Sync.fetchScalar(
        "SELECT id FROM phone_tiktok_channels WHERE (member_1 = @loggedIn AND member_2 = @username) OR (member_1 = @username AND member_2 = @loggedIn)",
        {
            ["@loggedIn"] = username,
            ["@username"] = targetUsername
        }
    )
    
    if not channelId then
        return callback({success = false, error = "no_channel"})
    end
    
    callback({success = true, id = channelId})
end)