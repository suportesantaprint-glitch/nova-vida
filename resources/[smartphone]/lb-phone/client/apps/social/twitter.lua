local function formatTweetData(tweetData)
    if not tweetData then
        return {}
    end
    
    local attachments = tweetData.attachments
    if type(attachments) == "string" then
        attachments = json.decode(attachments)
    end
    
    if attachments then
        if type(attachments) ~= "table" or table.type(attachments) ~= "array" then
            attachments = nil
            debugprint("Malformed attachments for birdy post", tweetData.id)
        end
    end
    
    return {
        user = {
            profile_picture = tweetData.profile_image,
            name = tweetData.display_name,
            username = tweetData.username,
            verified = tweetData.verified == true,
            private = tweetData.private == true
        },
        tweet = {
            id = tweetData.id,
            content = tweetData.content,
            date_created = tweetData.timestamp,
            replies = tweetData.reply_count,
            likes = tweetData.like_count,
            retweets = tweetData.retweet_count,
            attachments = attachments,
            replyToId = tweetData.reply_to,
            liked = tweetData.liked == true,
            retweeted = tweetData.retweeted == true,
            replyToAuthor = tweetData.replyToAuthor,
            retweetedByName = tweetData.retweeted_by_display_name,
            retweetedByUsername = tweetData.retweeted_by_username
        }
    }
end

local function getTweetsWithPromotion(filters, page)
    local tweets = AwaitCallback("birdy:getPosts", filters, page)
    local formattedTweets = {}
    
    for i = 1, #tweets do
        formattedTweets[i] = formatTweetData(tweets[i])
    end
    
    local promotionIndex = math.random(3, 6)
    if promotionIndex >= #formattedTweets then
        promotionIndex = #formattedTweets - 1
    end
    
    if Config.PromoteBirdy and Config.PromoteBirdy.Enabled and #tweets > 1 then
        local promotedTweet = AwaitCallback("birdy:getRandomPromoted")
        if promotedTweet then
            local formattedPromoted = formatTweetData(promotedTweet)
            formattedPromoted.tweet.promoted = true
            table.insert(formattedTweets, promotionIndex, formattedPromoted)
        end
    end
    
    return formattedTweets
end

local interactionRequiredActions = {
    "login",
    "toggleFollow",
    "toggleLike", 
    "toggleRetweet",
    "sendMessage"
}

RegisterNUICallback("Twitter", function(data, callback)
    if not currentPhone then
        return
    end
    
    local action = data.action
    debugprint("Birdy: " .. (action or ""))
    
    if table.contains(interactionRequiredActions, action) then
        if not CanInteract() then
            return callback(false)
        end
    end
    
    if action == "createAccount" then
        local accountData = data.data
        TriggerCallback("birdy:createAccount", callback, accountData.name, accountData.username, accountData.password)
        
    elseif action == "changePassword" then
        TriggerCallback("birdy:changePassword", callback, data.oldPassword, data.newPassword)
        
    elseif action == "deleteAccount" then
        TriggerCallback("birdy:deleteAccount", callback, data.password)
        
    elseif action == "login" then
        local loginData = data.data
        TriggerCallback("birdy:login", callback, loginData.username, loginData.password)
        
    elseif action == "isLoggedIn" then
        TriggerCallback("birdy:isLoggedIn", callback)
        
    elseif action == "sendTweet" then
        local tweetData = data.data
        TriggerCallback("birdy:sendPost", callback, tweetData.content, tweetData.attachments, tweetData.replyTo, tweetData.hashtags)
        
    elseif action == "updateProfile" then
        TriggerCallback("birdy:updateProfile", callback, data.data)
        
    elseif action == "searchAccounts" then
        TriggerCallback("birdy:searchAccounts", function(accounts)
            local formattedAccounts = {}
            for i = 1, #accounts do
                local account = accounts[i]
                formattedAccounts[i] = {
                    username = account.username,
                    name = account.display_name,
                    profile_picture = account.profile_image,
                    verified = account.verified == true,
                    private = account.private == true
                }
            end
            callback(formattedAccounts)
        end, data.query)
        
    elseif action == "searchTweets" then
        TriggerCallback("birdy:searchTweets", function(tweets)
            local formattedTweets = {}
            for i = 1, #tweets do
                formattedTweets[i] = formatTweetData(tweets[i])
            end
            callback(formattedTweets)
        end, data.query, data.page)
        
    elseif action == "getProfile" then
        TriggerCallback("birdy:getProfile", function(profile)
            if not profile then
                debugprint("Birdy: failed to get profile", data.data.username)
                return callback()
            end
            
            if profile.pinnedTweet then
                profile.pinnedTweet = formatTweetData(profile.pinnedTweet)
            end
            
            callback(profile)
        end, data.data.username)
        
    elseif action == "getFollowers" then
        TriggerCallback("birdy:getData", callback, "followers", data.data.username, data.data.page)
        
    elseif action == "getFollowing" then
        TriggerCallback("birdy:getData", callback, "following", data.data.username, data.data.page)
        
    elseif action == "getLikes" then
        TriggerCallback("birdy:getData", callback, "likes", data.data.tweet_id, data.data.page)
        
    elseif action == "getRetweeters" then
        TriggerCallback("birdy:getData", callback, "retweeters", data.data.tweet_id, data.data.page)
        
    elseif action == "getTweets" then
        local filters = data.filter or data.filters
        if filters and next(filters) == nil then
            filters = nil
        end
        
        callback(getTweetsWithPromotion(filters, data.page))
        
    elseif action == "getTweet" then
        TriggerCallback("birdy:getPost", function(tweet)
            callback(formatTweetData(tweet))
        end, data.tweetId)
        
    elseif action == "getAuthor" then
        TriggerCallback("birdy:getAuthor", callback, data.tweetId)
        
    elseif action == "toggleFollow" then
        TriggerCallback("birdy:toggleFollow", callback, data.data.username, data.data.following)
        
    elseif action == "toggleNotifications" then
        TriggerCallback("birdy:toggleNotifications", callback, data.data.username, data.data.toggle)
        
    elseif action == "toggleLike" then
        TriggerCallback("birdy:toggleInteraction", callback, "like", data.tweet_id, data.liked)
        
    elseif action == "toggleRetweet" then
        TriggerCallback("birdy:toggleInteraction", callback, "retweet", data.tweet_id, data.retweeted)
        
    elseif action == "deleteTweet" then
        TriggerCallback("birdy:deletePost", callback, data.tweet_id)
        
    elseif action == "promoteTweet" then
        TriggerCallback("birdy:promotePost", callback, data.tweet_id)
        
    elseif action == "sendMessage" then
        local messageData = data.data
        TriggerCallback("birdy:sendMessage", callback, messageData.recipient, messageData.content, messageData.attachments)
        
    elseif action == "getMessages" then
        local messageData = data.data
        TriggerCallback("birdy:getMessages", function(messages)
            for i = 1, #messages do
                if messages[i].attachments then
                    messages[i].attachments = json.decode(messages[i].attachments)
                end
            end
            callback(messages)
        end, messageData.username, messageData.page)
        
    elseif action == "getRecentMessages" then
        TriggerCallback("birdy:getRecentMessages", callback, data.page)
        
    elseif action == "signOut" then
        TriggerCallback("birdy:signOut", callback)
        
    elseif action == "getNotifications" then
        TriggerCallback("birdy:getNotifications", function(notifications)
            for _, notification in pairs(notifications.notifications) do
                if notification.attachments then
                    notification.attachments = json.decode(notification.attachments)
                end
            end
            callback(notifications)
        end, data.page)
        
    elseif action == "getRecentHashtags" then
        TriggerCallback("birdy:getRecentHashtags", callback)
        
    elseif action == "pinTweet" then
        local tweetId = data.toggle and data.tweet_id or nil
        TriggerCallback("birdy:pinPost", callback, tweetId)
        
    elseif action == "getFollowRequests" then
        TriggerCallback("birdy:getFollowRequests", callback, data.page or 0)
        
    elseif action == "handleFollowRequest" then
        TriggerCallback("birdy:handleFollowRequest", callback, data.username, data.accept)
    end
end)

RegisterNetEvent("phone:twitter:updateTweetData", function(tweetId, data, increment)
    debugprint("updateTweetData", tweetId, data, increment)
    SendReactMessage("twitter:updateTweetData", {
        tweetId = tweetId,
        data = data,
        increment = increment
    })
end)

RegisterNetEvent("phone:twitter:updateProfileData", function(username, data, increment)
    debugprint("updateProfileData", username, data, increment)
    SendReactMessage("twitter:updateProfileData", {
        username = username,
        data = data,
        increment = increment
    })
end)

RegisterNetEvent("phone:twitter:newMessage", function(messageData)
    SendReactMessage("twitter:newMessage", messageData)
end)

RegisterNetEvent("phone:twitter:newtweet", function(tweetData)
    TriggerEvent("lb-phone:birdy:newPost", tweetData)
    SendReactMessage("twitter:newTweet", formatTweetData(tweetData))
end)

function SendTweet(data)
    assert(type(data) == "table", "Expected table for data, got " .. type(data))
    assert(type(data.content) == "string", "Expected string for data.content, got " .. type(data.content))
    assert(type(data.attachments) == "table", "Expected table / nil for data.attachments, got " .. type(data.attachments))
    assert(type(data.replyTo) == "string", "Expected string / nil for data.replyTo, got " .. type(data.replyTo))
    assert(type(data.hashtags) == "table", "Expected table / nil for data.hashtags, got " .. type(data.hashtags))
    
    if not CanInteract() then
        return
    end
    
    return AwaitCallback("birdy:sendPost", data.content, data.attachments, data.replyTo, data.hashtags)
end

exports("SendTweet", SendTweet)
exports("PostBirdy", SendTweet)