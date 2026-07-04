local function findDirectMessageChannel(senderNumber, recipientNumber)
    return MySQL.scalar.await([[
        SELECT c.id FROM phone_message_channels c
        WHERE c.is_group = 0
        AND EXISTS (SELECT TRUE FROM phone_message_members m WHERE m.channel_id = c.id AND m.phone_number = ?)
        AND EXISTS (SELECT TRUE FROM phone_message_members m WHERE m.channel_id = c.id AND m.phone_number = ?)
    ]], {senderNumber, recipientNumber})
end

local function sendMessage(senderNumber, recipientNumber, messageContent, attachments, callback, channelId)
    if not (channelId or recipientNumber) or not senderNumber then
        return
    end
    
    if not messageContent then
        if not attachments or #attachments == 0 then
            debugprint("No message or attachments provided")
            return
        end
    end
    
    if messageContent and #messageContent == 0 then
        messageContent = nil
        if not attachments or #attachments == 0 then
            debugprint("No attachments provided")
            return
        end
    end
    
    if not channelId then
        channelId = findDirectMessageChannel(senderNumber, recipientNumber)
    end
    
    local senderSource = GetSourceFromNumber(senderNumber)
    
    if not channelId then
        channelId = MySQL.insert.await("INSERT INTO phone_message_channels (is_group) VALUES (0)")
        
        MySQL.update.await(
            "INSERT INTO phone_message_members (channel_id, phone_number) VALUES (?, ?), (?, ?)",
            {channelId, senderNumber, channelId, recipientNumber}
        )
        
        local recipientSource = GetSourceFromNumber(recipientNumber)
        local timestamp = os.time() * 1000
        
        if senderSource then
            TriggerClientEvent("phone:messages:newChannel", senderSource, {
                id = channelId,
                lastMessage = messageContent,
                timestamp = timestamp,
                number = recipientNumber,
                isGroup = false,
                unread = false
            })
        end
        
        if recipientSource then
            TriggerClientEvent("phone:messages:newChannel", recipientSource, {
                id = channelId,
                lastMessage = messageContent,
                timestamp = timestamp,
                number = senderNumber,
                isGroup = false,
                unread = true
            })
        end
    end
    
    if senderSource then
        Log("Messages", senderSource, "info",
            L("BACKEND.LOGS.MESSAGE_TITLE"),
            L("BACKEND.LOGS.NEW_MESSAGE", {
                sender = FormatNumber(senderNumber),
                recipient = FormatNumber(recipientNumber),
                message = messageContent or "Attachment"
            })
        )
    end
    
    if type(attachments) == "table" then
        attachments = json.encode(attachments)
    end
    
    local messageId = MySQL.insert.await(
        "INSERT INTO phone_message_messages (channel_id, sender, content, attachments) VALUES (@channelId, @sender, @content, @attachments)",
        {
            ["@channelId"] = channelId,
            ["@sender"] = senderNumber,
            ["@content"] = messageContent,
            ["@attachments"] = attachments
        }
    )
    
    if not messageId then
        if callback then
            callback(false)
        end
        return
    end
    
    MySQL.update(
        "UPDATE phone_message_channels SET last_message = ? WHERE id = ?",
        {string.sub(messageContent or "Attachment", 1, 50), channelId}
    )
    
    MySQL.update(
        "UPDATE phone_message_members SET unread = unread + 1 WHERE channel_id = ? AND phone_number != ?",
        {channelId, senderNumber}
    )
    
    MySQL.update(
        "UPDATE phone_message_members SET deleted = 0 WHERE channel_id = ?",
        {channelId}
    )
    
    local channelMembers = MySQL.query.await(
        "SELECT phone_number FROM phone_message_members WHERE channel_id = ? AND phone_number != ?",
        {channelId, senderNumber}
    )
    
    for i = 1, #channelMembers do
        local memberNumber = channelMembers[i].phone_number
        if memberNumber ~= senderNumber then
            local memberSource = GetSourceFromNumber(memberNumber)
            if memberSource then
                TriggerClientEvent("phone:messages:newMessage", memberSource, channelId, messageId, senderNumber, messageContent, attachments)
            end
            
            if messageContent ~= "<!CALL-NO-ANSWER!>" then
                local contact = GetContact(senderNumber, memberNumber)
                
                SendNotification(memberNumber, {
                    app = "Messages",
                    title = contact and contact.name or senderNumber,
                    content = messageContent,
                    thumbnail = attachments and json.decode(attachments)[1] or nil,
                    avatar = contact and contact.avatar or nil,
                    showAvatar = true
                })
            end
        end
    end
    
    if callback then
        callback(channelId)
    end
    
    TriggerEvent("lb-phone:messages:messageSent", {
        channelId = channelId,
        messageId = messageId,
        sender = senderNumber,
        recipient = recipientNumber,
        message = messageContent,
        attachments = attachments
    })
    
    return {
        channelId = channelId,
        messageId = messageId
    }
end

SendMessage = sendMessage

exports("SentMoney", function(senderNumber, recipientNumber, amount)
    assert(type(senderNumber) == "string", "Expected string for argument 1, got " .. type(senderNumber))
    assert(type(recipientNumber) == "string", "Expected string for argument 2, got " .. type(recipientNumber))
    assert(type(amount) == "number", "Expected number for argument 3, got " .. type(amount))
    
    SendMessage(senderNumber, recipientNumber, "<!SENT-PAYMENT-" .. math.floor(amount + 0.5) .. "!>")
end)

exports("SendCoords", function(senderNumber, recipientNumber, coordinates)
    assert(type(senderNumber) == "string", "Expected string for argument 1, got " .. type(senderNumber))
    assert(type(recipientNumber) == "string", "Expected string for argument 2, got " .. type(recipientNumber))
    assert(type(coordinates) == "vector2", "Expected vector2 for argument 3, got " .. type(coordinates))
    
    SendMessage(senderNumber, recipientNumber, "<!SENT-LOCATION-X=" .. coordinates.x .. "Y=" .. coordinates.y .. "!>")
end)

exports("SendMessage", function(senderNumber, recipientNumber, messageContent, attachments, callback, channelId)
    assert(type(senderNumber) == "string", "Expected string for argument 1, got " .. type(senderNumber))
    assert(type(recipientNumber) == "string", "Expected string or nil for argument 2, got " .. type(recipientNumber))
    assert(type(messageContent) == "string", "Expected string or nil for argument 3, got " .. type(messageContent))
    assert(type(attachments) == "table", "Expected table, string or nil for argument 4, got " .. type(attachments))
    assert(type(callback) == "function", "Expected function or nil for argument 5, got " .. type(callback))
    
    return SendMessage(senderNumber, recipientNumber, messageContent, attachments, callback, channelId)
end)

BaseCallback("messages:sendMessage", function(source, senderNumber, recipientNumber, messageContent, attachments, channelId)
    if ContainsBlacklistedWord(source, "Messages", messageContent) then
        return false
    end
    
    return SendMessage(senderNumber, recipientNumber, messageContent, attachments, nil, channelId)
end)

BaseCallback("messages:createGroup", function(source, ownerNumber, memberNumbers, initialMessage, attachments)
    local groupId = MySQL.insert.await("INSERT INTO phone_message_channels (is_group) VALUES (1)")
    
    if not groupId then
        return false
    end
    
    local members = {{number = ownerNumber, isOwner = true}}
    
    MySQL.update.await(
        "INSERT INTO phone_message_members (channel_id, phone_number, is_owner) VALUES (?, ?, 1)",
        {groupId, ownerNumber}
    )
    
    for i = 1, #memberNumbers do
        local memberNumber = memberNumbers[i]
        MySQL.update.await(
            "INSERT INTO phone_message_members (channel_id, phone_number, is_owner) VALUES (?, ?, 0)",
            {groupId, memberNumber}
        )
        members[i + 1] = {number = memberNumber, isOwner = false}
    end
    
    local groupData = {
        id = groupId,
        lastMessage = initialMessage,
        timestamp = os.time() * 1000,
        name = nil,
        isGroup = true,
        members = members,
        unread = false
    }
    
    for i = 1, #memberNumbers do
        local memberSource = GetSourceFromNumber(memberNumbers[i])
        if memberSource then
            TriggerClientEvent("phone:messages:newChannel", memberSource, groupData)
        end
    end
    
    TriggerClientEvent("phone:messages:newChannel", source, groupData)
    
    return SendMessage(ownerNumber, nil, initialMessage, attachments, nil, groupId)
end)

BaseCallback("messages:renameGroup", function(source, phoneNumber, groupId, newName)
    local affectedRows = MySQL.update.await(
        "UPDATE phone_message_channels SET `name` = ? WHERE id = ? AND is_group = 1",
        {newName, groupId}
    )
    
    local success = affectedRows > 0
    
    if success then
        TriggerClientEvent("phone:messages:renameGroup", -1, groupId, newName)
    end
    
    return success
end)

BaseCallback("messages:getRecentMessages", function(source, phoneNumber)
    return MySQL.query.await([[
        SELECT
        channel.id AS channel_id,
        channel.is_group,
        channel.`name`,
        channel.last_message,
        channel.last_message_timestamp,
        channel_member.phone_number,
        channel_member.is_owner,
        channel_member.unread,
        channel_member.deleted
        FROM
        phone_message_members target_member

        INNER JOIN phone_message_channels channel
        ON channel.id = target_member.channel_id

        INNER JOIN phone_message_members channel_member
        ON channel_member.channel_id = channel.id

        WHERE
        target_member.phone_number = ?

        ORDER BY
        channel.last_message_timestamp DESC
    ]], {phoneNumber})
end)

BaseCallback("messages:getMessages", function(source, phoneNumber, channelId, page)
    return MySQL.query.await([[
        SELECT id, sender, content, attachments, `timestamp`
        FROM phone_message_messages

        WHERE channel_id = ? AND EXISTS (SELECT TRUE FROM phone_message_members m WHERE m.channel_id = ? AND m.phone_number = ?)

        ORDER BY `timestamp` DESC
        LIMIT ?, ?
    ]], {channelId, channelId, phoneNumber, page * 25, 25})
end)

BaseCallback("messages:deleteMessage", function(source, phoneNumber, messageId, channelId)
    if not Config.DeleteMessages then
        return false
    end
    
    local isLastMessage = MySQL.scalar.await(
        "SELECT MAX(id) FROM phone_message_messages WHERE channel_id = ?",
        {channelId}
    ) == messageId
    
    local affectedRows = MySQL.update.await(
        "DELETE FROM phone_message_messages WHERE id = ? AND sender = ? AND channel_id = ?",
        {messageId, phoneNumber, channelId}
    )
    
    local success = affectedRows > 0
    
    if success and isLastMessage then
        MySQL.update.await(
            "UPDATE phone_message_channels SET last_message = ? WHERE id = ?",
            {L("APPS.MESSAGES.MESSAGE_DELETED"), channelId}
        )
    end
    
    if success then
        TriggerClientEvent("phone:messages:messageDeleted", -1, channelId, messageId, isLastMessage)
    end
    
    return success
end)

BaseCallback("messages:addMember", function(source, phoneNumber, channelId, newMemberNumber)
    local affectedRows = MySQL.update.await(
        "INSERT IGNORE INTO phone_message_members (channel_id, phone_number) VALUES (?, ?)",
        {channelId, newMemberNumber}
    )
    
    local success = affectedRows > 0
    local newMemberSource = GetSourceFromNumber(newMemberNumber)
    
    if not success then
        return false
    end
    
    TriggerClientEvent("phone:messages:memberAdded", -1, channelId, newMemberNumber)
    
    if not newMemberSource then
        return true
    end
    
    local members = MySQL.Sync.fetchAll(
        "SELECT phone_number AS `number`, is_owner AS isOwner FROM phone_message_members WHERE channel_id = ?",
        {channelId}
    )
    
    local channelInfo = MySQL.single.await(
        "SELECT `name`, last_message, last_message_timestamp FROM phone_message_channels WHERE id = ?",
        {channelId}
    )
    
    if #members > 0 and channelInfo then
        TriggerClientEvent("phone:messages:newChannel", newMemberSource, {
            id = channelId,
            lastMessage = channelInfo.last_message,
            timestamp = channelInfo.last_message_timestamp,
            name = channelInfo.name,
            isGroup = true,
            members = members,
            unread = false
        })
    end
    
    return true
end)

BaseCallback("messages:removeMember", function(source, phoneNumber, channelId, memberToRemove)
    local isOwner = MySQL.scalar.await(
        "SELECT is_owner FROM phone_message_members WHERE channel_id = ? AND phone_number = ?",
        {channelId, phoneNumber}
    )
    
    if not isOwner then
        return false
    end
    
    local affectedRows = MySQL.update.await(
        "DELETE FROM phone_message_members WHERE channel_id = ? AND phone_number = ?",
        {channelId, memberToRemove}
    )
    
    local success = affectedRows > 0
    
    if success then
        TriggerClientEvent("phone:messages:memberRemoved", -1, channelId, memberToRemove)
    end
    
    return success
end)

BaseCallback("messages:leaveGroup", function(source, phoneNumber, channelId)
    local isOwner = MySQL.scalar.await(
        "SELECT is_owner FROM phone_message_members WHERE channel_id = ? AND phone_number = ?",
        {channelId, phoneNumber}
    )
    
    if isOwner then
        MySQL.update.await([[
            UPDATE phone_message_members m
            SET is_owner = TRUE
            WHERE m.channel_id = ?
            AND m.phone_number != ?
            LIMIT 1
        ]], {channelId, phoneNumber})
        
        local newOwner = MySQL.scalar.await(
            "SELECT phone_number FROM phone_message_members WHERE channel_id = ? AND is_owner = TRUE",
            {channelId}
        )
        
        TriggerClientEvent("phone:messages:ownerChanged", -1, channelId, newOwner)
    end
    
    local affectedRows = MySQL.update.await(
        "DELETE FROM phone_message_members WHERE channel_id = ? AND phone_number = ?",
        {channelId, phoneNumber}
    )
    
    local success = affectedRows > 0
    
    local isEmpty = MySQL.scalar.await(
        "SELECT COUNT(1) FROM phone_message_members WHERE channel_id = ?",
        {channelId}
    ) == 0
    
    if success then
        TriggerClientEvent("phone:messages:memberRemoved", -1, channelId, phoneNumber)
    end
    
    if isEmpty then
        MySQL.update.await(
            "DELETE FROM phone_message_channels WHERE id = ?",
            {channelId}
        )
        debugprint("Deleted group " .. channelId .. "due to it being empty")
    end
    
    return success
end)

BaseCallback("messages:markRead", function(source, phoneNumber, channelId)
    MySQL.update.await(
        "UPDATE phone_message_members SET unread = 0 WHERE channel_id = ? AND phone_number = ?",
        {channelId, phoneNumber}
    )
    return true
end)

BaseCallback("messages:deleteConversations", function(source, phoneNumber, channelIds)
    if type(channelIds) ~= "table" then
        debugprint("expected table, got " .. type(channelIds))
        return false
    end
    
    MySQL.update.await(
        "UPDATE phone_message_members SET deleted = 1 WHERE channel_id IN (?) AND phone_number = ?",
        {channelIds, phoneNumber}
    )
    
    return true
end)