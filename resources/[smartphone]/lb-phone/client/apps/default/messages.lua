local restrictedActions = {"sendMessage", "createGroup", "renameGroup"}

RegisterNUICallback("Messages", function(data, callback)
    if not currentPhone then
        return
    end
    
    local action = data.action
    debugprint("Messages:" .. (action or ""))
    
    if table.contains(restrictedActions, action) then
        if not CanInteract() then
            return callback(false)
        end
    end
    
    if data.attachments and #data.attachments > 0 then
        data.attachments = json.encode(data.attachments)
    else
        data.attachments = nil
    end
    
    if action == "sendMessage" then
        TriggerServerEvent("phone:messages:messageSent", data.number, data.content, data.attachments)
        TriggerCallback("messages:sendMessage", callback, data.number, data.content, data.attachments, data.id)
    elseif action == "createGroup" then
        local memberNumbers = {}
        for i = 1, #data.members do
            memberNumbers[i] = data.members[i].number
        end
        TriggerCallback("messages:createGroup", callback, memberNumbers, data.content, data.attachments)
    elseif action == "renameGroup" then
        TriggerCallback("messages:renameGroup", callback, data.id, data.name)
    elseif action == "getRecentMessages" then
        local serverMessages = AwaitCallback("messages:getRecentMessages")
        local conversations = {}
        
        local function findConversationIndex(channelId)
            for i = 1, #conversations do
                if conversations[i].id == channelId then
                    return i
                end
            end
            return false
        end
        
        for i = 1, #serverMessages do
            local message = serverMessages[i]
            local existingIndex = findConversationIndex(message.channel_id)
            
            if not existingIndex then
                if message.is_group then
                    table.insert(conversations, {
                        id = message.channel_id,
                        lastMessage = message.last_message,
                        timestamp = message.last_message_timestamp,
                        name = message.name,
                        isGroup = true,
                        members = {{isOwner = message.is_owner, number = message.phone_number}}
                    })
                elseif message.phone_number ~= currentPhone then
                    table.insert(conversations, {
                        id = message.channel_id,
                        lastMessage = message.last_message,
                        timestamp = message.last_message_timestamp,
                        number = message.phone_number,
                        isGroup = false
                    })
                end
            elseif message.is_group then
                table.insert(conversations[existingIndex].members, {
                    isOwner = message.is_owner,
                    number = message.phone_number
                })
            end
        end
        
        for i = 1, #serverMessages do
            local message = serverMessages[i]
            local conversationIndex = findConversationIndex(message.channel_id)
            
            if conversationIndex and message.phone_number == currentPhone then
                conversations[conversationIndex].deleted = message.deleted
                conversations[conversationIndex].unread = message.unread > 0
            end
        end
        
        callback(conversations)
    elseif action == "getMessages" then
        TriggerCallback("messages:getMessages", function(messages)
            for i = 1, #messages do
                messages[i].attachments = json.decode(messages[i].attachments or "[]")
            end
            callback(messages)
        end, data.id, data.page)
    elseif action == "deleteMessage" then
        if Config.DeleteMessages then
            TriggerCallback("messages:deleteMessage", callback, data.id, data.channel)
        end
    elseif action == "addMember" then
        TriggerCallback("messages:addMember", callback, data.id, data.number)
    elseif action == "removeMember" then
        TriggerCallback("messages:removeMember", callback, data.id, data.number)
    elseif action == "leaveGroup" then
        TriggerCallback("messages:leaveGroup", callback, data.id)
    elseif action == "markRead" then
        TriggerCallback("messages:markRead", callback, data.id)
    elseif action == "deleteConversations" then
        TriggerCallback("messages:deleteConversations", callback, data.channels)
    end
end)

RegisterNetEvent("phone:messages:newMessage", function(channelId, messageId, sender, content, attachments)
    SendReactMessage("messages:newMessage", {
        channelId = channelId,
        messageId = messageId,
        sender = sender,
        content = content,
        attachments = attachments and json.decode(attachments) or {}
    })
end)

RegisterNetEvent("phone:messages:messageDeleted", function(channelId, messageId, isLastMessage)
    SendReactMessage("messages:messageDeleted", {
        channelId = channelId,
        messageId = messageId,
        isLastMessage = isLastMessage
    })
end)

RegisterNetEvent("phone:messages:renameGroup", function(channelId, newName)
    SendReactMessage("messages:renameGroup", {
        channelId = channelId,
        name = newName
    })
end)

RegisterNetEvent("phone:messages:memberAdded", function(channelId, memberNumber)
    SendReactMessage("messages:addMember", {
        channelId = channelId,
        number = memberNumber
    })
end)

RegisterNetEvent("phone:messages:memberRemoved", function(channelId, memberNumber)
    SendReactMessage("messages:removeMember", {
        channelId = channelId,
        number = memberNumber
    })
end)

RegisterNetEvent("phone:messages:ownerChanged", function(channelId, newOwnerNumber)
    SendReactMessage("messages:changeOwner", {
        channelId = channelId,
        number = newOwnerNumber
    })
end)

RegisterNetEvent("phone:messages:newChannel", function(channelData)
    SendReactMessage("messages:newChannel", channelData)
end)