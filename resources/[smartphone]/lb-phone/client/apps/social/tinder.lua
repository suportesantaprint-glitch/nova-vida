local interactionRequiredActions = {
    "createAccount",
    "saveProfile", 
    "sendMessage"
}

RegisterNUICallback("Tinder", function(data, callback)
    if not currentPhone then
        return
    end
    
    local action = data.action
    debugprint("Spark: " .. (action or ""))
    
    if table.contains(interactionRequiredActions, action) then
        if not CanInteract() then
            return callback(false)
        end
    end
    
    if action == "createAccount" then
        TriggerCallback("tinder:createAccount", callback, data.data)
        
    elseif action == "deleteAccount" then
        TriggerCallback("tinder:deleteAccount", callback)
        
    elseif action == "saveProfile" then
        TriggerCallback("tinder:updateAccount", callback, data.data)
        
    elseif action == "isLoggedIn" then
        local accountData = AwaitCallback("tinder:isLoggedIn")
        if not accountData then
            return callback(false)
        end
        
        local profileData = {
            name = accountData.name,
            photos = json.decode(accountData.photos),
            dob = accountData.dob,
            bio = accountData.bio,
            showMen = accountData.interested_men,
            showWomen = accountData.interested_women,
            isMale = accountData.is_male,
            active = accountData.active
        }
        
        callback(profileData)
        
    elseif action == "getFeed" then
        local feedData = AwaitCallback("tinder:getFeed", data.page)
        local formattedFeed = {}
        
        for i = 1, #feedData do
            local profile = feedData[i]
            formattedFeed[i] = {
                name = profile.name,
                dob = profile.dob,
                bio = profile.bio,
                photos = json.decode(profile.photos),
                number = profile.phone_number
            }
        end
        
        callback(formattedFeed)
        
    elseif action == "swipe" then
        TriggerCallback("tinder:swipe", callback, data.number, data.like)
        
    elseif action == "getMatches" then
        local matchesData = AwaitCallback("tinder:getMatches")
        local formattedMatches = {
            newMatches = {},
            messages = {}
        }
        
        for i = 1, #matchesData do
            local match = matchesData[i]
            local formattedMatch = {
                name = match.name,
                number = match.phone_number,
                photos = json.decode(match.photos),
                dob = match.dob,
                bio = match.bio,
                isMale = match.is_male
            }
            
            if match.latest_message then
                formattedMatch.lastMessage = match.latest_message
                table.insert(formattedMatches.messages, formattedMatch)
            else
                table.insert(formattedMatches.newMatches, formattedMatch)
            end
        end
        
        callback(formattedMatches)
        
    elseif action == "sendMessage" then
        local messageData = data.data
        
        if messageData.attachments and #messageData.attachments == 0 then
            messageData.attachments = nil
        end
        
        local attachments = nil
        if messageData.attachments then
            attachments = json.encode(messageData.attachments)
        end
        
        TriggerCallback("tinder:sendMessage", callback, messageData.recipient, messageData.content, attachments)
        
    elseif action == "getMessages" then
        local messages = AwaitCallback("tinder:getMessages", data.number, data.page)
        
        for i = 1, #messages do
            if messages[i].attachments then
                messages[i].attachments = json.decode(messages[i].attachments)
            else
                messages[i].attachments = {}
            end
        end
        
        callback(messages)
    end
end)

RegisterNetEvent("phone:tinder:receiveMessage", function(messageData)
    if messageData.attachments then
        messageData.attachments = json.decode(messageData.attachments)
    else
        messageData.attachments = {}
    end
    
    SendReactMessage("tinder:newMessage", messageData)
end)