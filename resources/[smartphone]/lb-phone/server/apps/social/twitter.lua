

local function GetLoggedInTwitterUsername(source)
    local phoneNumber = GetEquippedPhoneNumber(source)
    if not phoneNumber then
        return false
    end
    return GetLoggedInAccount(phoneNumber, "Twitter")
end

local function CreateTwitterCallback(name, callback, fallback, options)
    BaseCallback("birdy:" .. name, function(source, phoneNumber, username, ...)
        local loggedUsername = GetLoggedInAccount(phoneNumber, "Twitter")
        if not loggedUsername then
            return fallback
        end
        return callback(source, phoneNumber, loggedUsername, ...)
    end, fallback, options)
end

local function NotifyAllDevices(username, notification, excludeNumber)
    local phoneNumbers = MySQL.query.await(
        "SELECT phone_number FROM phone_logged_in_accounts WHERE username = ? AND app = 'Twitter' AND `active` = 1",
        {username}
    )
    
    notification.app = "Twitter"
    
    for i = 1, #phoneNumbers do
        local phoneNumber = phoneNumbers[i].phone_number
        if phoneNumber ~= excludeNumber then
            SendNotification(phoneNumber, notification)
        end
    end
end

local function GetProfileData(username, phoneNumber)
    username = username:lower()
    
    local profileData = MySQL.single.await(
        "SELECT `display_name`, `bio`, `profile_image`, `profile_header`, `verified`, `follower_count`, `following_count`, `date_joined`, private FROM `phone_twitter_accounts` WHERE `username`=?",
        {username}
    )
    
    if not profileData then
        return false
    end
    
    local isFollowing = false
    local isFollowingYou = false
    local notificationsEnabled = false
    local requested = false
    local pinnedTweet = nil
    
    local loggedUsername = phoneNumber and GetLoggedInAccount(phoneNumber, "Twitter")
    
    if loggedUsername then
        isFollowing = MySQL.scalar.await(
            "SELECT `followed` FROM `phone_twitter_follows` WHERE `follower` = ? AND `followed` = ?",
            {loggedUsername, username}
        ) ~= nil
        
        isFollowingYou = MySQL.scalar.await(
            "SELECT `followed` FROM `phone_twitter_follows` WHERE `follower` = ? AND `followed` = ?",
            {username, loggedUsername}
        ) ~= nil
        
        notificationsEnabled = MySQL.scalar.await(
            "SELECT `notifications` FROM `phone_twitter_follows` WHERE `follower` = ? AND `followed` = ?",
            {loggedUsername, username}
        ) == true
        
        requested = MySQL.scalar.await(
            "SELECT TRUE FROM phone_twitter_follow_requests WHERE requester = ? AND requestee = ?",
            {loggedUsername, username}
        ) ~= nil
        
        local pinnedTweetId = MySQL.scalar.await(
            "SELECT pinned_tweet FROM phone_twitter_accounts WHERE username = ?",
            {username}
        )
        
        if pinnedTweetId then
            pinnedTweet = GetTweet(pinnedTweetId, loggedUsername)
        end
    end
    
    return {
        name = profileData.display_name,
        username = username,
        followers = profileData.follower_count,
        following = profileData.following_count,
        date_joined = profileData.date_joined,
        bio = profileData.bio,
        verified = profileData.verified,
        private = profileData.private,
        profile_picture = profileData.profile_image,
        header = profileData.profile_header,
        isFollowing = isFollowing,
        isFollowingYou = isFollowingYou,
        notificationsEnabled = notificationsEnabled,
        pinnedTweet = pinnedTweet,
        requested = requested
    }
end

local function GetLoggedInPhoneNumbers(username)
    local phoneNumbers = {}
    local results = MySQL.Sync.fetchAll(
        "SELECT phone_number FROM phone_logged_in_accounts WHERE username = ? AND app = 'Twitter' AND `active` = 1",
        {username}
    )
    
    for i = 1, #results do
        local phoneNumber = results[i].phone_number
        local source = GetSourceFromNumber(results[i].phone_number)
        phoneNumbers[phoneNumber] = source
    end
    
    return phoneNumbers
end

local notificationTypes = {
    like = "BACKEND.TWITTER.LIKE",
    retweet = "BACKEND.TWITTER.RETWEET",
    reply = "BACKEND.TWITTER.REPLY",
    follow = "BACKEND.TWITTER.FOLLOW",
    tweet = "BACKEND.TWITTER.TWEET"
}

local function CreateNotification(targetUsername, fromUsername, type, tweetId)
    if targetUsername == fromUsername then
        return
    end
    
    local notificationKey = notificationTypes[type]
    if not notificationKey then
        return
    end
    
    if type == "like" or type == "retweet" or type == "follow" then
        local query = "SELECT TRUE FROM phone_twitter_notifications WHERE username=@username AND `from`=@from AND `type`=@type"
        if type ~= "follow" then
            query = query .. " AND tweet_id=@tweet_id"
        end
        
        local exists = MySQL.Sync.fetchScalar(query, {
            ["@username"] = targetUsername,
            ["@from"] = fromUsername,
            ["@type"] = type,
            ["@tweet_id"] = tweetId
        })
        
        if exists then
            return
        end
    end
    
    local senderData = MySQL.Sync.fetchAll(
        "SELECT display_name, private FROM phone_twitter_accounts WHERE username=@username",
        {["@username"] = fromUsername}
    )[1]
    
    if senderData and (senderData.private and type ~= "reply") then
        return
    end
    
    local notificationTitle = L(notificationKey, {
        displayName = senderData.display_name,
        username = fromUsername
    })
    
    MySQL.Async.execute(
        "INSERT INTO phone_twitter_notifications (id, username, `from`, `type`, tweet_id) VALUES (@id, @username, @from, @type, @tweetId)",
        {
            ["@id"] = GenerateId("phone_twitter_notifications", "id"),
            ["@username"] = targetUsername,
            ["@from"] = fromUsername,
            ["@type"] = type,
            ["@tweetId"] = tweetId
        }
    )
    
    local thumbnail = nil
    local content = nil
    
    if type ~= "follow" then
        local tweetData = MySQL.Sync.fetchAll(
            "SELECT content, attachments FROM phone_twitter_tweets WHERE id=@tweetId",
            {["@tweetId"] = tweetId}
        )
        
        if tweetData then
            content = tweetData[1].content
            local attachments = tweetData[1].attachments
            if attachments then
                attachments = json.decode(tweetData[1].attachments)
                thumbnail = attachments[1]
            end
        end
    end
    
    local phoneNumbers = GetLoggedInPhoneNumbers(targetUsername)
    for phoneNumber, source in pairs(phoneNumbers) do
        SendNotification(phoneNumber, {
            app = "Twitter",
            title = notificationTitle,
            content = content,
            thumbnail = thumbnail
        })
    end
end

RegisterLegacyCallback("birdy:getNotifications", function(source, callback, page)
    local username = GetLoggedInTwitterUsername(source)
    if not username then
        return callback({
            notifications = {},
            requests = 0
        })
    end
    
    MySQL.Sync.fetchAll(
        [[
            SELECT
                -- notification data
                n.`from`, n.`type`, n.tweet_id,
                -- tweet data
                t.username, t.content, t.attachments, t.reply_to, t.like_count,
                t.reply_count, t.retweet_count, t.`timestamp`,

                (
                    SELECT TRUE FROM phone_twitter_likes l
                    WHERE l.tweet_id=t.id AND l.username=@username
                ) AS liked,
                (
                    SELECT TRUE FROM phone_twitter_retweets r
                    WHERE r.tweet_id=t.id AND r.username=@username
                ) AS retweeted,

                -- account data
                a.display_name AS `name`, a.profile_image AS profile_picture, a.verified,
                (
                    CASE WHEN t.reply_to IS NULL THEN NULL ELSE (SELECT username FROM phone_twitter_tweets WHERE id=t.reply_to LIMIT 1) END
                ) AS replyToAuthor

            FROM phone_twitter_notifications n

            LEFT JOIN phone_twitter_tweets t
                ON n.tweet_id = t.id

            JOIN phone_twitter_accounts a
                ON a.username = n.from

            WHERE n.username=@username

            ORDER BY n.`timestamp` DESC

            LIMIT @page, @perPage
        ]],
        {
            ["@page"] = page * 15,
            ["@perPage"] = 15,
            ["@username"] = username
        },
        function(notifications)
            if page > 0 then
                return callback({
                    notifications = notifications
                })
            end
            
            callback({
                notifications = notifications,
                requests = MySQL.Sync.fetchScalar(
                    "SELECT COUNT(1) FROM phone_twitter_follow_requests WHERE requestee=@username",
                    {["@username"] = username}
                )
            })
        end
    )
end)

RegisterLegacyCallback("birdy:createAccount", function(source, callback, displayName, username, password)
    local phoneNumber = GetEquippedPhoneNumber(source)
    if not phoneNumber then
        return callback(false)
    end
    
    username = username:lower()
    
    if not IsUsernameValid(username) then
        return callback({
            success = false,
            error = "USERNAME_NOT_ALLOWED"
        })
    end
    
    local existingUser = MySQL.Sync.fetchScalar(
        "SELECT TRUE FROM phone_twitter_accounts WHERE username=@username",
        {["@username"] = username}
    )
    
    if existingUser then
        return callback({
            success = false,
            error = "USERNAME_TAKEN"
        })
    end
    
    MySQL.Sync.execute(
        "INSERT INTO phone_twitter_accounts (display_name, username, `password`, phone_number) VALUES (@displayName, @username, @password, @phonenumber)",
        {
            ["@displayName"] = displayName,
            ["@username"] = username,
            ["@password"] = GetPasswordHash(password),
            ["@phonenumber"] = phoneNumber
        }
    )
    
    AddLoggedInAccount(phoneNumber, "Twitter", username)
    callback({success = true})
    
    if Config.AutoFollow.Enabled and Config.AutoFollow.Birdy.Enabled then
        for i = 1, #Config.AutoFollow.Birdy.Accounts do
            MySQL.update.await(
                "INSERT INTO phone_twitter_follows (followed, follower) VALUES (?, ?)",
                {Config.AutoFollow.Birdy.Accounts[i], username}
            )
        end
    end
end, {preventSpam = true, rateLimit = 4})

CreateTwitterCallback("changePassword", function(source, phoneNumber, username, oldPassword, newPassword)
    if not Config.ChangePassword.Birdy then
        infoprint("warning", ("%s tried to change password on Birdy, but it's not enabled in the config."):format(source))
        return false
    end
    
    if oldPassword == newPassword or #newPassword < 3 then
        debugprint("same password / too short")
        return false
    end
    
    local storedPassword = MySQL.scalar.await(
        "SELECT password FROM phone_twitter_accounts WHERE username = ?",
        {username}
    )
    
    if not storedPassword or not VerifyPasswordHash(oldPassword, storedPassword) then
        return false
    end
    
    local success = MySQL.update.await(
        "UPDATE phone_twitter_accounts SET password = ? WHERE username = ?",
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
        "DELETE FROM phone_logged_in_accounts WHERE username = ? AND app = 'Twitter' AND phone_number != ?",
        {username, phoneNumber}
    )
    
    ClearActiveAccountsCache("Twitter", username, phoneNumber)
    
    Log("Birdy", source, "info", L("BACKEND.LOGS.CHANGED_PASSWORD.TITLE"),
        L("BACKEND.LOGS.CHANGED_PASSWORD.DESCRIPTION", {
            number = phoneNumber,
            username = username,
            app = "Birdy"
        })
    )
    
    TriggerClientEvent("phone:logoutFromApp", -1, {
        username = username,
        app = "twitter",
        reason = "password",
        number = phoneNumber
    })
    
    return true
end, false)

CreateTwitterCallback("deleteAccount", function(source, phoneNumber, username, password)
    if not Config.DeleteAccount.Birdy then
        infoprint("warning", ("%s tried to delete their account on Birdy, but it's not enabled in the config."):format(source))
        return false
    end
    
    local storedPassword = MySQL.scalar.await(
        "SELECT password FROM phone_twitter_accounts WHERE username = ?",
        {username}
    )
    
    if not storedPassword or not VerifyPasswordHash(password, storedPassword) then
        return false
    end
    
    local success = MySQL.update.await(
        "DELETE FROM phone_twitter_accounts WHERE username = ?",
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
        "DELETE FROM phone_logged_in_accounts WHERE username = ? AND app = 'Twitter'",
        {username}
    )
    
    ClearActiveAccountsCache("Twitter", username)
    
    Log("Birdy", source, "info", L("BACKEND.LOGS.DELETED_ACCOUNT.TITLE"),
        L("BACKEND.LOGS.DELETED_ACCOUNT.DESCRIPTION", {
            number = phoneNumber,
            username = username,
            app = "Birdy"
        })
    )
    
    TriggerClientEvent("phone:logoutFromApp", -1, {
        username = username,
        app = "twitter",
        reason = "deleted"
    })
    
    return true
end, false)

BaseCallback("birdy:login", function(source, phoneNumber, username, password)
    username = username:lower()
    
    local storedPassword = MySQL.scalar.await(
        "SELECT `password` FROM phone_twitter_accounts WHERE username = ?",
        {username}
    )
    
    if not storedPassword then
        return {
            success = false,
            error = "INVALID_ACCOUNT"
        }
    end
    
    if not VerifyPasswordHash(password, storedPassword) then
        return {
            success = false,
            error = "INVALID_PASSWORD"
        }
    end
    
    AddLoggedInAccount(phoneNumber, "Twitter", username)
    local accountData = GetProfileData(username)
    
    if not accountData then
        return {
            success = false,
            error = "INVALID_ACCOUNT"
        }
    end
    
    return {
        success = true,
        data = accountData
    }
end)

CreateTwitterCallback("isLoggedIn", function(source, phoneNumber, username)
    return GetProfileData(username)
end, false)

CreateTwitterCallback("getProfile", function(source, phoneNumber, username, targetUsername)
    return GetProfileData(targetUsername, phoneNumber)
end, false)

RegisterLegacyCallback("birdy:pinPost", function(source, callback, tweetId)
    local username = GetLoggedInTwitterUsername(source)
    if not username then
        return callback(false)
    end
    
    if tweetId then
        local ownsPost = MySQL.scalar.await(
            "SELECT TRUE FROM phone_twitter_tweets WHERE id = ? AND username = ?",
            {tweetId, username}
        )
        
        if not ownsPost then
            infoprint("warning", ("%s (%s) tried to pin a post on birdy that they didn't make."):format(username, source))
            return callback(false)
        end
    end
    
    MySQL.Async.execute(
        "UPDATE phone_twitter_accounts SET pinned_tweet=@tweetId WHERE username=@username",
        {
            ["@tweetId"] = tweetId or nil,
            ["@username"] = username
        },
        function()
            callback(true)
        end
    )
end)

RegisterLegacyCallback("birdy:signOut", function(source, callback)
    local phoneNumber = GetEquippedPhoneNumber(source)
    if not phoneNumber then
        return callback(false)
    end
    
    local username = GetLoggedInAccount(phoneNumber, "Twitter")
    if not username then
        return callback(false)
    end
    
    RemoveLoggedInAccount(phoneNumber, "Twitter", username)
    callback(true)
end)

RegisterLegacyCallback("birdy:updateProfile", function(source, callback, profileData)
    local username = GetLoggedInTwitterUsername(source)
    if not username then
        return callback(false)
    end
    
    local name = profileData.name
    local bio = profileData.bio
    local profile_picture = profileData.profile_picture
    local header = profileData.header
    local private = profileData.private
    
    MySQL.Async.execute(
        "UPDATE phone_twitter_accounts SET display_name=@displayName, bio=@bio, profile_image=@profilePicture, profile_header=@header, private=@private WHERE username=@username",
        {
            ["@username"] = username,
            ["@displayName"] = name,
            ["@bio"] = bio,
            ["@profilePicture"] = profile_picture,
            ["@header"] = header,
            ["@private"] = private
        },
        function()
            callback(true)
        end
    )
end)

local function LogPost(tweetId, username, content, attachments, source)
    local attachmentCount = 0
    if attachments and #attachments then
        attachmentCount = #attachments
    end
    
    local logContent = "**Username**: " .. username .. "\n\n**Content**: " .. (content or "")
    
    if attachments then
        logContent = logContent .. "\n\n**Attachments**:"
        for i = 1, attachmentCount do
            logContent = logContent .. "\n\n[Attachment " .. i .. "](" .. attachments[i] .. ")"
        end
    end
    
    logContent = logContent .. "\n\n**ID**: " .. tweetId
    
    Log("Birdy", source, "info", "New post", logContent)
end

local function SendDiscordWebhook(username, content, attachments, replyTo)
    if not (Config.Post.Birdy and not replyTo) then
        return
    end
    
    if not (BIRDY_WEBHOOK and BIRDY_WEBHOOK:sub(-14) == "/api/webhooks/") then
        return
    end
    
    local avatar = MySQL.scalar.await(
        "SELECT profile_image FROM phone_twitter_accounts WHERE username = ?",
        {username}
    )
    
    PerformHttpRequest(BIRDY_WEBHOOK, function() end, "POST", json.encode({
        username = Config.Post.Accounts.Birdy and Config.Post.Accounts.Birdy.Username or "Birdy",
        avatar_url = Config.Post.Accounts.Birdy and Config.Post.Accounts.Birdy.Avatar or "https://loaf-scripts.com/fivem/lb-phone/icons/Birdy.png",
        embeds = {{
            title = L("APPS.TWITTER.NEW_POST"),
            description = content and #content > 0 and content or nil,
            color = 1942002,
            timestamp = GetTimestampISO(),
            author = {
                name = "@" .. username,
                icon_url = avatar or "https://cdn.discordapp.com/embed/avatars/5.png"
            },
            image = attachments and #attachments > 0 and {
                url = attachments[1]
            } or nil,
            footer = {
                text = "LB Phone",
                icon_url = "https://docs.lbscripts.com/images/icons/icon.png"
            }
        }}
    }), {["Content-Type"] = "application/json"})
end

local function PostBirdy(username, content, attachments, replyTo, hashtags, source)
    if not content then
        content = ""
    end
    
    assert(type(username) == "string", "PostBirdy: Expected string for argument 1 (username), got " .. type(username))
    assert(type(content) == "string", "PostBirdy: Expected string/nil for argument 2 (content), got " .. type(content))
    
    local tweetId = GenerateId("phone_twitter_tweets", "id")
    local values = {tweetId, username, content}
    local query = "INSERT INTO phone_twitter_tweets (id, username, content"
    
    if attachments then
        if type(attachments) == "table" then
            if table.type(attachments) == "array" and #attachments > 0 then
                query = query .. ", attachments"
                table.insert(values, json.encode(attachments))
            end
        else
            error("PostBirdy: Expected table/nil for argument 3 (attachments), got " .. type(attachments))
        end
    elseif content:gsub(" ", ""):len() == 0 then
        debugprint("PostBirdy: No content & no attachments")
        return false
    end
    
    if replyTo then
        if type(replyTo) == "string" then
            query = query .. ", reply_to"
            table.insert(values, replyTo)
        else
            error("PostBirdy: Expected string/nil for argument 4 (replyTo), got " .. type(replyTo))
        end
    end
    
    local placeholders = ("?, "):rep(#values):sub(1, -3)
    query = query .. ") VALUES (" .. placeholders .. ")"
    
    local insertResult = MySQL.update.await(query, values)
    if insertResult == 0 then
        return false
    end
    
    local profileData = MySQL.single.await(
        "SELECT display_name, profile_image, verified, private FROM phone_twitter_accounts WHERE username = ?",
        {username}
    )
    
    if not profileData then
        profileData = {display_name = username}
    end
    
    if replyTo then
        MySQL.update.await(
            "UPDATE phone_twitter_tweets SET reply_count = reply_count + 1 WHERE id = ?",
            {replyTo}
        )
        
        TriggerClientEvent("phone:twitter:updateTweetData", -1, replyTo, "replies", true)
        
        MySQL.scalar.await(
            "SELECT username FROM phone_twitter_tweets WHERE id = ?",
            {replyTo},
            function(originalAuthor)
                if originalAuthor then
                    CreateNotification(originalAuthor, username, "reply", tweetId)
                end
            end
        )
    end
    
    MySQL.query.await(
        "SELECT follower FROM phone_twitter_follows WHERE followed = ? AND notifications=1",
        {username},
        function(followers)
            for i = 1, #followers do
                CreateNotification(followers[i].follower, username, "tweet", tweetId)
            end
        end
    )
    
    TrackSocialMediaPost("birdy", attachments)
    
    if source then
        LogPost(tweetId, username, content, attachments, source)
    end
    
    if not profileData.private then
        SendDiscordWebhook(username, content, attachments, replyTo)
        
        if Config.BirdyNotifications then
            local notificationType = Config.BirdyNotifications == "all" and "all" or "online"
            
            NotifyEveryone(notificationType, {
                app = "Twitter",
                title = L("BACKEND.TWITTER.TWEET", {username = username}),
                content = content,
                thumbnail = attachments and attachments[1] or nil
            })
        end
        
        if Config.BirdyTrending.Enabled and type(hashtags) == "table" and table.type(hashtags) == "array" and #hashtags > 0 then
            local hashtagQuery = "INSERT INTO phone_twitter_hashtags (hashtag, amount) VALUES " ..
                                ("(?, 1), "):rep(#hashtags):sub(1, -3) ..
                                " ON DUPLICATE KEY UPDATE amount = amount + 1"
            MySQL.update.await(hashtagQuery, hashtags)
        end
        
        local tweetData = {
            id = tweetId,
            username = username,
            content = content,
            attachments = attachments,
            like_count = 0,
            reply_count = 0,
            retweet_count = 0,
            reply_to = replyTo,
            timestamp = os.time() * 1000,
            liked = false,
            retweeted = false,
            display_name = profileData.display_name,
            profile_image = profileData.profile_image,
            verified = profileData.verified
        }
        
        if replyTo then
            local replyToAuthor = MySQL.scalar.await(
                "SELECT username FROM phone_twitter_tweets WHERE id = ?",
                {replyTo}
            )
            tweetData.replyToAuthor = replyToAuthor
        end
        
        TriggerClientEvent("phone:twitter:newtweet", -1, tweetData)
        TriggerEvent("lb-phone:birdy:newPost", tweetData)
    end
    
    return true, tweetId
end

exports("PostBirdy", PostBirdy)

CreateTwitterCallback("sendPost", function(source, phoneNumber, username, content, attachments, replyTo, hashtags)
    if ContainsBlacklistedWord(content, "Birdy", source) then
        return false
    end
    
    return PostBirdy(username, content, attachments, replyTo, hashtags, source)
end, nil, {preventSpam = true, rateLimit = 15})

RegisterCallback("birdy:getRecentHashtags", function()
    if Config.BirdyTrending.Enabled then
        return MySQL.query.await("SELECT hashtag, amount AS uses FROM phone_twitter_hashtags ORDER BY amount DESC LIMIT 5")
    end
    return {}
end)

RegisterLegacyCallback("birdy:deletePost", function(source, callback, tweetId)
    local username = GetLoggedInTwitterUsername(source)
    if not username then
        return callback(false)
    end
    
    local replyTo = MySQL.Sync.fetchScalar(
        "SELECT reply_to FROM phone_twitter_tweets WHERE id=@id",
        {["@id"] = tweetId}
    )
    
    local hasPermission = IsAdmin(source)
    if not hasPermission then
        hasPermission = MySQL.Sync.fetchScalar(
            "SELECT TRUE FROM phone_twitter_tweets WHERE id=@id AND username=@username",
            {["@id"] = tweetId, ["@username"] = username}
        )
    end
    
    if not hasPermission then
        return callback(false)
    end
    
    local deleteParams = {["@id"] = tweetId}
    
    MySQL.Sync.execute("DELETE FROM phone_twitter_likes WHERE tweet_id=@id", deleteParams)
    MySQL.Sync.execute("DELETE FROM phone_twitter_retweets WHERE tweet_id=@id", deleteParams)
    MySQL.Sync.execute("DELETE FROM phone_twitter_notifications WHERE tweet_id=@id", deleteParams)
    
    local deletedRows = MySQL.Sync.execute("DELETE FROM phone_twitter_tweets WHERE id=@id", deleteParams)
    local success = deletedRows > 0
    
    callback(success)
    
    if not success then
        return
    end
    
    if replyTo then
        local replyCount = MySQL.Sync.fetchScalar(
            "SELECT COUNT(id) FROM phone_twitter_tweets WHERE reply_to=@replyTo",
            {["@replyTo"] = replyTo}
        )
        
        MySQL.Sync.execute(
            "UPDATE phone_twitter_tweets SET reply_count=@count WHERE id=@replyTo",
            {["@replyTo"] = replyTo, ["@count"] = replyCount}
        )
        
        TriggerClientEvent("phone:twitter:updateTweetData", -1, replyTo, "replies", false)
    end
    
    Log("Birdy", source, "info", "Post deleted", "**ID**: " .. tweetId)
end)

RegisterLegacyCallback("birdy:getRandomPromoted", function(source, callback)
    local username = GetLoggedInTwitterUsername(source)
    if not username then
        return callback(false)
    end
    
    local promotedTweetId = MySQL.Sync.fetchScalar(
        "SELECT tweet_id FROM phone_twitter_promoted WHERE promotions > 0 ORDER BY RAND() LIMIT 1"
    )
    
    if not promotedTweetId then
        return callback(false)
    end
    
    MySQL.Async.execute(
        "UPDATE phone_twitter_promoted SET promotions = promotions - 1, views = views + 1 WHERE tweet_id = @tweetId",
        {["@tweetId"] = promotedTweetId}
    )
    
    callback(GetTweet(promotedTweetId))
end)

RegisterLegacyCallback("birdy:promotePost", function(source, callback, tweetId)
    if not (Config.PromoteBirdy and Config.PromoteBirdy.Enabled and RemoveMoney) then
        return callback(false)
    end
    
    if not RemoveMoney(source, Config.PromoteBirdy.Cost) then
        return callback(false)
    end
    
    MySQL.Async.execute(
        [[INSERT INTO phone_twitter_promoted (tweet_id, promotions, views) VALUES (@tweetId, @promotions, 0)
        ON DUPLICATE KEY UPDATE promotions = promotions + @promotions]],
        {
            ["@tweetId"] = tweetId,
            ["@promotions"] = Config.PromoteBirdy.Views
        }
    )
    
    callback(true)
end)

RegisterLegacyCallback("birdy:searchAccounts", function(source, callback, searchTerm)
    MySQL.Async.fetchAll(
        [[SELECT display_name, username, profile_image, verified, private
        FROM phone_twitter_accounts
        WHERE username LIKE CONCAT(@search, "%") OR display_name LIKE CONCAT("%", @search, "%")]],
        {["@search"] = searchTerm},
        callback
    )
end)

RegisterLegacyCallback("birdy:searchTweets", function(source, callback, searchTerm, page)
    local username = GetLoggedInTwitterUsername(source)
    if not username then
        return callback(false)
    end
    
    MySQL.Async.fetchAll(
        [[SELECT DISTINCT t.id, t.username, t.content, t.attachments,
            t.like_count, t.reply_count, t.retweet_count, t.reply_to, t.`timestamp`,
            
            (CASE WHEN t.reply_to IS NULL THEN NULL ELSE 
                (SELECT username FROM phone_twitter_tweets WHERE id=t.reply_to LIMIT 1) END
            ) AS replyToAuthor,
            
            a.display_name, a.username, a.profile_image, a.verified,
            
            (SELECT TRUE FROM phone_twitter_likes l
                WHERE l.tweet_id=t.id AND l.username=@loggedInAs) AS liked,
            (SELECT TRUE FROM phone_twitter_retweets r
                WHERE r.tweet_id=t.id AND r.username=@loggedInAs) AS retweeted
                
        FROM phone_twitter_tweets t
        LEFT JOIN phone_twitter_accounts a ON a.username=t.username
        WHERE t.content LIKE CONCAT("%", @search, "%")
        ORDER BY t.`timestamp` DESC
        LIMIT @page, @perPage]],
        {
            ["@search"] = searchTerm,
            ["@loggedInAs"] = username,
            ["@page"] = page * 10,
            ["@perPage"] = 10
        },
        callback
    )
end)

RegisterLegacyCallback("birdy:getData", function(source, callback, dataType, targetValue, page)
    local username = GetLoggedInTwitterUsername(source)
    if not username then
        return callback(false)
    end
    
    local tableName = "phone_twitter_likes"
    local column1 = "tweet_id"
    local column2 = "username"
    
    if dataType == "following" or dataType == "followers" then
        tableName = "phone_twitter_follows"
        if dataType == "following" then
            column1 = "follower"
            column2 = "followed"
        else
            column1 = "followed"
            column2 = "follower"
        end
    elseif dataType == "retweeters" then
        tableName = "phone_twitter_retweets"
        column1 = "tweet_id"
        column2 = "username"
    end
    
    local query = string.format([[
        SELECT
            a.display_name AS `name`,
            a.username,
            a.profile_image AS profile_picture,
            a.bio,
            a.verified,
            
            (SELECT CASE WHEN f.followed IS NULL THEN FALSE ELSE TRUE END
                FROM phone_twitter_follows f
                WHERE f.follower=@loggedInAs AND a.username=f.followed) AS isFollowing,
                
            (SELECT CASE WHEN f.follower IS NULL THEN FALSE ELSE TRUE END
                FROM phone_twitter_follows f
                WHERE f.follower=a.username AND f.followed=@loggedInAs) AS isFollowingYou
                
        FROM %s w
        JOIN phone_twitter_accounts a ON a.username=w.%s
        WHERE w.%s=@whereValue
        ORDER BY a.username DESC
        LIMIT @page, @perPage
    ]], tableName, column2, column1)
    
    MySQL.Async.fetchAll(query, {
        ["@loggedInAs"] = username,
        ["@whereValue"] = targetValue,
        ["@page"] = page * 20,
        ["@perPage"] = 20
    }, callback)
end)

function GetTweet(tweetId, loggedInAs)
    if not tweetId then
        return
    end
    
    local tweets = MySQL.Sync.fetchAll([[
        SELECT DISTINCT t.id, t.username, t.content, t.attachments,
            t.like_count, t.reply_count, t.retweet_count, t.reply_to, t.`timestamp`,
            
            (CASE WHEN t.reply_to IS NULL THEN NULL ELSE 
                (SELECT username FROM phone_twitter_tweets WHERE id=t.reply_to LIMIT 1) END
            ) AS replyToAuthor,
            
            a.display_name, a.username, a.profile_image, a.verified,
            
            (SELECT TRUE FROM phone_twitter_likes l
                WHERE l.tweet_id=t.id AND l.username=@loggedInAs) AS liked,
            (SELECT TRUE FROM phone_twitter_retweets r
                WHERE r.tweet_id=t.id AND r.username=@loggedInAs) AS retweeted
                
        FROM phone_twitter_tweets t
        INNER JOIN phone_twitter_accounts a ON a.username=t.username
        WHERE t.id=@tweetId AND (a.private=0 OR a.username=@loggedInAs OR (
            SELECT TRUE FROM phone_twitter_follows f
            WHERE f.follower=@loggedInAs AND f.followed=a.username
        ))
    ]], {
        ["@tweetId"] = tweetId,
        ["@loggedInAs"] = loggedInAs
    })
    
    return tweets and tweets[1] or nil
end

exports("GetTweet", function(tweetId, callback)
    assert(type(tweetId) == "string", "Expected string for argument 1, got " .. type(tweetId))
    infoprint("warning", "GetTweet is deprecated, use GetBirdyPost instead")
    
    MySQL.Async.fetchAll([[
        SELECT DISTINCT t.id, t.username, t.content, t.attachments,
            t.like_count, t.reply_count, t.retweet_count, t.reply_to, t.`timestamp`,
            a.display_name, a.username, a.profile_image, a.verified
        FROM (phone_twitter_tweets t, phone_twitter_accounts a)
        WHERE t.id=@tweetId AND t.username=a.username
    ]], {["@tweetId"] = tweetId}, callback)
end)

exports("GetBirdyPost", function(tweetId)
    local post = MySQL.single.await([[
        SELECT
            t.id,
            t.username,
            t.content,
            t.attachments,
            t.like_count AS likes,
            t.reply_count AS replies,
            t.retweet_count AS reposts,
            t.reply_to AS replyTo,
            t.`timestamp`,
            a.display_name AS displayName,
            a.profile_image AS avatar,
            a.verified
        FROM phone_twitter_tweets t
        LEFT JOIN phone_twitter_accounts a ON a.username = t.username
        WHERE t.id = ?
    ]], {tweetId})
    
    if post then
        post.attachments = post.attachments and json.decode(post.attachments) or nil
    end
    
    return post
end)

RegisterLegacyCallback("birdy:getPost", function(source, callback, tweetId)
    local username = GetLoggedInTwitterUsername(source)
    if not username then
        return callback(false)
    end
    
    callback(GetTweet(tweetId, username))
end)

RegisterLegacyCallback("birdy:getPosts", function(source, callback, options, page)
    local username = GetLoggedInTwitterUsername(source)
    if not username then
        return callback({})
    end
    
    local whereClause = ""
    local joinClause = ""
    local orderBy = "`timestamp` DESC"
    local includeRetweets = false
    local retweetJoin = ""
    local retweetWhere = ""
    
    if not options then
        whereClause = "t.reply_to IS NULL"
        includeRetweets = true
    else
        if options.type == "following" then
            whereClause = "t.reply_to IS NULL AND f.follower=@loggedInAs AND f.followed=t.username"
            joinClause = "JOIN phone_twitter_follows f"
            retweetJoin = "JOIN phone_twitter_follows f ON f.follower=@loggedInAs AND r.username=f.followed"
            includeRetweets = true
        elseif options.type == "replyTo" then
            whereClause = "t.reply_to=@replyTo"
            orderBy = "t.like_count DESC, t.timestamp DESC"
        elseif options.type == "user" then
            whereClause = "t.username=@username AND t.reply_to IS NULL"
            retweetWhere = " AND r.username=@username"
            includeRetweets = true
        elseif options.type == "media" then
            whereClause = "t.username=@username AND t.attachments IS NOT NULL"
        elseif options.type == "replies" then
            whereClause = "t.username=@username AND t.reply_to IS NOT NULL"
        elseif options.type == "liked" then
            whereClause = "l.username=@username AND t.id=l.tweet_id"
            joinClause = "JOIN phone_twitter_likes l"
            orderBy = "l.timestamp DESC"
        end
    end
    
    local mainQuery = string.format([[
        SELECT
            (CASE WHEN t.reply_to IS NULL THEN NULL ELSE 
                (SELECT username FROM phone_twitter_tweets WHERE id=t.reply_to LIMIT 1) END
            ) AS replyToAuthor,
            
            t.id, t.username, t.content, t.attachments,
            t.like_count, t.reply_count, t.retweet_count, t.reply_to, t.`timestamp`,
            
            a.display_name, a.profile_image, a.verified, a.private,
            
            (SELECT TRUE FROM phone_twitter_likes l2
                WHERE l2.tweet_id=t.id AND l2.username=@loggedInAs) AS liked,
            (SELECT TRUE FROM phone_twitter_retweets r2
                WHERE r2.tweet_id=t.id AND r2.username=@loggedInAs) AS retweeted,
                
            NULL AS tweet_timestamp, NULL AS retweeted_by_display_name, NULL AS retweeted_by_username
            
        FROM phone_twitter_tweets t
        INNER JOIN phone_twitter_accounts a ON a.username=t.username
        %s
        WHERE (a.private=0 OR a.username=@loggedInAs OR (
            SELECT TRUE FROM phone_twitter_follows f
            WHERE f.follower=@loggedInAs AND f.followed=a.username
        )) AND %s
    ]], joinClause, whereClause)
    
    if includeRetweets then
        local retweetQuery = string.format([[
            UNION ALL
            SELECT
                (CASE WHEN t.reply_to IS NULL THEN NULL ELSE 
                    (SELECT username FROM phone_twitter_tweets WHERE id=t.reply_to LIMIT 1) END
                ) AS replyToAuthor,
                
                t.id, t.username, t.content, t.attachments,
                t.like_count, t.reply_count, t.retweet_count, t.reply_to, r.timestamp,
                
                a.display_name, a.profile_image, a.verified, a.private,
                
                (SELECT TRUE FROM phone_twitter_likes l2
                    WHERE l2.tweet_id=t.id AND l2.username=@loggedInAs) AS liked,
                (SELECT TRUE FROM phone_twitter_retweets r2
                    WHERE r2.tweet_id=t.id AND r2.username=@loggedInAs) AS retweeted,
                    
                t.`timestamp` AS tweet_timestamp,
                (SELECT display_name FROM phone_twitter_accounts a2
                    WHERE r.username=a2.username) AS retweeted_by_display_name,
                r.username AS retweeted_by_username
                
            FROM phone_twitter_tweets t
            INNER JOIN phone_twitter_accounts a ON a.username=t.username
            JOIN phone_twitter_retweets r ON r.tweet_id=t.id
            %s
            WHERE (a.private=0 OR a.username=@loggedInAs OR (
                SELECT TRUE FROM phone_twitter_follows f
                WHERE f.follower=@loggedInAs AND f.followed=a.username
            )) %s
        ]], retweetJoin, retweetWhere)
        
        mainQuery = mainQuery .. retweetQuery
    end
    
    local finalQuery = mainQuery .. string.format("ORDER BY %s LIMIT @page, @perPage", orderBy)
    
    MySQL.Async.fetchAll(finalQuery, {
        ["@page"] = page * 10,
        ["@perPage"] = 10,
        ["@username"] = options and options.username or nil,
        ["@replyTo"] = options and options.tweet_id or nil,
        ["@loggedInAs"] = username
    }, callback)
end)

local interactions = {
    like = {
        table = "phone_twitter_likes",
        column1 = "username",
        column2 = "tweet_id"
    },
    retweet = {
        table = "phone_twitter_retweets",
        column1 = "username",
        column2 = "tweet_id"
    }
}

RegisterLegacyCallback("birdy:toggleInteraction", function(source, callback, interactionType, tweetId, enable)
    if interactionType ~= "like" and interactionType ~= "retweet" then
        return
    end
    
    local username = GetLoggedInTwitterUsername(source)
    if not username then
        return callback(not enable)
    end
    
    local function onComplete(affectedRows)
        if affectedRows == 0 then
            return callback(not enable)
        else
            callback(enable)
        end
        
        local dataType = interactionType == "like" and "likes" or "retweets"
        TriggerClientEvent("phone:twitter:updateTweetData", -1, tweetId, dataType, enable == true)
        
        if enable then
            local tweetAuthor = MySQL.Sync.fetchScalar(
                "SELECT username FROM phone_twitter_tweets WHERE id=@tweetId",
                {["@tweetId"] = tweetId}
            )
            CreateNotification(tweetAuthor, username, interactionType, tweetId)
        end
    end
    
    local interaction = interactions[interactionType]
    local tableName = interaction.table
    local column1 = interaction.column1
    local column2 = interaction.column2
    
    if enable then
        local insertQuery = string.format(
            "INSERT IGNORE INTO %s (%s, %s) VALUES (@loggedInAs, @tweetId)",
            tableName, column1, column2
        )
        MySQL.Async.execute(insertQuery, {
            ["@loggedInAs"] = username,
            ["@tweetId"] = tweetId
        }, onComplete)
    else
        local deleteQuery = string.format(
            "DELETE FROM %s WHERE %s=@loggedInAs AND %s=@tweetId",
            tableName, column1, column2
        )
        MySQL.Async.execute(deleteQuery, {
            ["@loggedInAs"] = username,
            ["@tweetId"] = tweetId
        }, onComplete)
    end
end, {preventSpam = true, rateLimit = 30})

RegisterLegacyCallback("birdy:toggleNotifications", function(source, callback, targetUsername, enable)
    local username = GetLoggedInTwitterUsername(source)
    if not username then
        return callback(not enable)
    end
    
    MySQL.Async.execute(
        "UPDATE phone_twitter_follows SET notifications=@enabled WHERE follower=@loggedInAs AND followed=@username",
        {
            ["@enabled"] = enable,
            ["@loggedInAs"] = username,
            ["@username"] = targetUsername
        },
        function(affectedRows)
            callback(affectedRows > 0 and enable or not enable)
        end
    )
end)

RegisterLegacyCallback("birdy:toggleFollow", function(source, callback, targetUsername, follow)
    local username = GetLoggedInTwitterUsername(source)
    if not username or targetUsername == username then
        return callback(not follow)
    end
    
    local params = {
        ["@loggedInAs"] = username,
        ["@username"] = targetUsername
    }
    
    local isPrivate = MySQL.Sync.fetchScalar(
        "SELECT private FROM phone_twitter_accounts WHERE username=@username",
        params
    )
    
    if isPrivate and follow then
        MySQL.Async.execute(
            "INSERT IGNORE INTO phone_twitter_follow_requests (requester, requestee) VALUES (@loggedInAs, @username)",
            params,
            function(affectedRows)
                callback(follow)
                if affectedRows == 0 then
                    return
                end
                
                local phoneNumbers = GetLoggedInPhoneNumbers(targetUsername)
                for phoneNumber, source in pairs(phoneNumbers) do
                    SendNotification(phoneNumber, {
                        app = "Twitter",
                        content = L("BACKEND.TWITTER.NEW_FOLLOW_REQUEST", {username = username})
                    })
                end
            end
        )
        return
    elseif isPrivate and not follow then
        MySQL.Async.execute(
            "DELETE FROM phone_twitter_follow_requests WHERE requester=@loggedInAs AND requestee=@username",
            params
        )
    end
    
    local query = follow and 
        "INSERT IGNORE INTO phone_twitter_follows (followed, follower) VALUES (@username, @loggedInAs)" or
        "DELETE FROM phone_twitter_follows WHERE followed=@username AND follower=@loggedInAs"
    
    MySQL.Async.execute(query, params, function(affectedRows)
        if affectedRows == 0 then
            return callback(not follow)
        end
        
        TriggerClientEvent("phone:twitter:updateProfileData", -1, targetUsername, "followers", follow == true)
        TriggerClientEvent("phone:twitter:updateProfileData", -1, username, "following", follow == true)
        
        if follow then
            CreateNotification(targetUsername, username, "follow")
        end
        
        callback(follow)
    end)
end, {preventSpam = true, rateLimit = 30})

RegisterLegacyCallback("birdy:getFollowRequests", function(source, callback, page)
    local username = GetLoggedInTwitterUsername(source)
    if not username then
        return callback({})
    end
    
    MySQL.Async.fetchAll([[
        SELECT a.username, a.display_name AS `name`, a.profile_image AS profile_picture, a.verified,
            (SELECT CASE WHEN f.follower IS NULL THEN FALSE ELSE TRUE END
                FROM phone_twitter_follows f
                WHERE f.follower=a.username AND f.followed=@loggedInAs) AS isFollowingYou
                
        FROM phone_twitter_follow_requests r
        INNER JOIN phone_twitter_accounts a ON a.username=r.requester
        WHERE r.requestee=@loggedInAs
        ORDER BY r.`timestamp` DESC
        LIMIT @page, @perPage
    ]], {
        ["@loggedInAs"] = username,
        ["@page"] = (page or 0) * 15,
        ["@perPage"] = 15
    }, callback)
end)

RegisterLegacyCallback("birdy:handleFollowRequest", function(source, callback, requesterUsername, accept)
    local username = GetLoggedInTwitterUsername(source)
    if not username then
        return callback(false)
    end
    
    local params = {
        ["@loggedInAs"] = username,
        ["@username"] = requesterUsername
    }
    
    local deletedRows = MySQL.Sync.execute(
        "DELETE FROM phone_twitter_follow_requests WHERE requestee=@loggedInAs AND requester=@username",
        params
    )
    
    if deletedRows == 0 then
        return callback(false)
    end
    
    if not accept then
        return callback(true)
    end
    
    MySQL.Sync.execute(
        "INSERT IGNORE INTO phone_twitter_follows (follower, followed) VALUES (@username, @loggedInAs)",
        params
    )
    
    TriggerClientEvent("phone:twitter:updateProfileData", -1, username, "followers", true)
    TriggerClientEvent("phone:twitter:updateProfileData", -1, requesterUsername, "following", true)
    
    CreateNotification(username, requesterUsername, "follow")
    
    local phoneNumbers = GetLoggedInPhoneNumbers(requesterUsername)
    for phoneNumber, source in pairs(phoneNumbers) do
        SendNotification(phoneNumber, {
            app = "Twitter",
            content = L("BACKEND.TWITTER.FOLLOW_REQUEST_ACCEPTED_DESCRIPTION", {username = username})
        })
    end
    
    callback(true)
end)

CreateTwitterCallback("sendMessage", function(source, phoneNumber, senderUsername, recipientUsername, content, attachments)
    if ContainsBlacklistedWord(content, "Birdy", source) then
        return false
    end
    
    local insertResult = MySQL.update.await([[
        INSERT INTO phone_twitter_messages (id, sender, recipient, content, attachments)
        VALUES (@id, @sender, @recipient, @content, @attachments)
    ]], {
        ["@id"] = GenerateId("phone_twitter_messages", "id"),
        ["@sender"] = senderUsername,
        ["@recipient"] = recipientUsername,
        ["@content"] = content,
        ["@attachments"] = attachments and json.encode(attachments) or nil
    })
    
    if insertResult == 0 then
        return false
    end
    
    local recipientPhones = GetLoggedInPhoneNumbers(recipientUsername)
    for phoneNumber, source in pairs(recipientPhones) do
        if source then
            TriggerClientEvent("phone:twitter:newMessage", source, {
                sender = senderUsername,
                recipient = recipientUsername,
                content = content,
                attachments = attachments,
                timestamp = os.time() * 1000
            })
        end
    end
    
    local senderData = GetProfileData(senderUsername)
    if not senderData then
        return true
    end
    
    for phoneNumber, source in pairs(recipientPhones) do
        SendNotification(phoneNumber, {
            source = source,
            app = "Twitter",
            title = senderData.name,
            content = content,
            thumbnail = attachments and attachments[1] or nil,
            avatar = senderData.profile_picture,
            showAvatar = true
        })
    end
    
    return true
end, nil, {preventSpam = true, rateLimit = 15})

RegisterLegacyCallback("birdy:getMessages", function(source, callback, otherUsername, page)
    local username = GetLoggedInTwitterUsername(source)
    if not username then
        return callback({})
    end
    
    MySQL.Async.fetchAll([[
        SELECT sender, recipient, content, attachments, `timestamp`
        FROM phone_twitter_messages
        WHERE (sender=@loggedInAs AND recipient=@username) OR (sender=@username AND recipient=@loggedInAs)
        ORDER BY `timestamp` DESC
        LIMIT @page, @perPage
    ]], {
        ["@loggedInAs"] = username,
        ["@username"] = otherUsername,
        ["@page"] = page * 25,
        ["@perPage"] = 25
    }, callback)
end)

RegisterLegacyCallback("birdy:getRecentMessages", function(source, callback, page)
    local username = GetLoggedInTwitterUsername(source)
    if not username then
        return callback({})
    end
    
    MySQL.Async.fetchAll([[
        SELECT
            m.content, m.attachments, m.sender, f_m.username, m.`timestamp`,
            a.display_name AS `name`, a.profile_image AS profile_picture, a.verified
            
        FROM phone_twitter_messages m
        
        JOIN ((
            SELECT (CASE WHEN recipient!=@loggedInAs THEN recipient ELSE sender END) AS username, 
                   MAX(`timestamp`) AS `timestamp`
            FROM phone_twitter_messages
            WHERE sender=@loggedInAs OR recipient=@loggedInAs
            GROUP BY username
        ) f_m) ON m.`timestamp`=f_m.`timestamp`
        
        INNER JOIN phone_twitter_accounts a ON a.username=f_m.username
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

CreateThread(function()
    if not Config.BirdyTrending.Enabled then
        return
    end
    
    while not DatabaseCheckerFinished do
        Wait(500)
    end
    
    while true do
        local resetHours = Config.BirdyTrending.Reset or 24
        MySQL.Async.execute(
            string.format("DELETE FROM phone_twitter_hashtags WHERE last_used < DATE_SUB(NOW(), INTERVAL %s HOUR)", 
                         tostring(resetHours)),
            {}
        )
        
        Wait(3600000)
    end
end)
