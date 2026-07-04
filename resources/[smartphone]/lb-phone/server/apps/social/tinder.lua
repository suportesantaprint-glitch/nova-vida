BaseCallback("tinder:createAccount", function(source, phoneNumber, accountData)
    local existingAccount = MySQL.scalar.await("SELECT TRUE FROM phone_tinder_accounts WHERE phone_number = ?", {phoneNumber})
    
    if existingAccount then
        return false
    end
    
    local insertQuery = [[
        INSERT INTO phone_tinder_accounts
        (`name`, phone_number, photos, bio, dob, is_male, interested_men, interested_women)
        VALUES
        (@name, @phoneNumber, @photos, @bio, @dob, @isMale, @showMen, @showWomen)
    ]]
    
    local parameters = {
        ["@name"] = accountData.name,
        ["@phoneNumber"] = phoneNumber,
        ["@photos"] = json.encode(accountData.photos),
        ["@bio"] = accountData.bio,
        ["@dob"] = accountData.dob,
        ["@isMale"] = accountData.isMale,
        ["@showMen"] = accountData.showMen,
        ["@showWomen"] = accountData.showWomen
    }
    
    local result = MySQL.update.await(insertQuery, parameters)
    return result > 0
end, false)

BaseCallback("tinder:deleteAccount", function(source, phoneNumber)
    if not Config.DeleteAccount.Spark then
        infoprint("warning", source .. " tried to delete their spark account, but it's not enabled in the config.")
        return false
    end
    
    local deleteAccount = MySQL.update.await("DELETE FROM phone_tinder_accounts WHERE phone_number = ?", {phoneNumber})
    
    if deleteAccount <= 0 then
        return false
    end
    
    MySQL.update("DELETE FROM phone_tinder_swipes WHERE swiper = ? OR swipee = ?", {phoneNumber, phoneNumber})
    MySQL.update("DELETE FROM phone_tinder_matches WHERE phone_number_1 = ? OR phone_number_2 = ?", {phoneNumber, phoneNumber})
    MySQL.update("DELETE FROM phone_tinder_messages WHERE sender = ? OR recipient = ?", {phoneNumber, phoneNumber})
    
    return true
end)

BaseCallback("tinder:updateAccount", function(source, phoneNumber, accountData)
    local updateQuery = [[
        UPDATE phone_tinder_accounts
        SET
        `name`=@name,
        photos=@photos,
        bio=@bio,
        is_male=@isMale,
        interested_men=@showMen,
        interested_women=@showWomen,
        `active`=@active
        WHERE phone_number=@phoneNumber
    ]]
    
    local parameters = {
        ["@name"] = accountData.name,
        ["@photos"] = json.encode(accountData.photos),
        ["@bio"] = accountData.bio,
        ["@isMale"] = accountData.isMale,
        ["@showMen"] = accountData.showMen,
        ["@showWomen"] = accountData.showWomen,
        ["@active"] = accountData.active,
        ["@phoneNumber"] = phoneNumber
    }
    
    local result = MySQL.update.await(updateQuery, parameters)
    return result > 0
end, false)

BaseCallback("tinder:isLoggedIn", function(source, phoneNumber)
    local accountData = MySQL.single.await("SELECT `name`, photos, bio, dob, is_male, interested_men, interested_women, `active` FROM phone_tinder_accounts WHERE phone_number = ?", {phoneNumber})
    
    if accountData then
        MySQL.update.await("UPDATE phone_tinder_accounts SET last_seen = NOW() WHERE phone_number = ?", {phoneNumber})
    end
    
    return accountData
end, false)

BaseCallback("tinder:getFeed", function(source, phoneNumber, page)
    local feedQuery = [[
        SELECT
        a.`name`, a.phone_number, a.photos, a.bio, a.dob
        FROM
        phone_tinder_accounts a
        JOIN
        phone_tinder_accounts b
        ON
        b.phone_number = @phoneNumber
        WHERE
        a.phone_number != @phoneNumber
        AND a.`active` = 1
        AND (a.is_male = b.interested_men OR a.is_male=(NOT b.interested_women))
        AND (a.interested_men=b.is_male OR a.interested_women=(NOT b.is_male))
        AND NOT EXISTS (SELECT TRUE FROM phone_tinder_swipes WHERE swiper = @phoneNumber AND swipee = a.phone_number)
        ORDER BY a.phone_number
        LIMIT @page, @perPage
    ]]
    
    local parameters = {
        ["@phoneNumber"] = phoneNumber,
        ["@page"] = page * 10,
        ["@perPage"] = 10
    }
    
    return MySQL.query.await(feedQuery, parameters)
end, {})

BaseCallback("tinder:swipe", function(source, phoneNumber, targetNumber, liked)
    local swipeResult = MySQL.query.await("INSERT INTO phone_tinder_swipes (swiper, swipee, liked) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE liked = ?", {phoneNumber, targetNumber, liked, liked})
    
    if swipeResult == 0 or not liked then
        return false
    end
    
    local mutualLike = MySQL.scalar.await("SELECT liked FROM phone_tinder_swipes WHERE swiper = ? AND swipee = ?", {targetNumber, phoneNumber})
    
    if mutualLike ~= true then
        return false
    end
    
    MySQL.update.await("INSERT INTO phone_tinder_matches (phone_number_1, phone_number_2) VALUES (?, ?)", {phoneNumber, targetNumber})
    
    local senderData = MySQL.single.await("SELECT `name`, photos FROM phone_tinder_accounts WHERE phone_number = ?", {phoneNumber})
    
    if not senderData then
        return
    end
    
    SendNotification(targetNumber, {
        app = "Tinder",
        title = L("BACKEND.TINDER.NEW_MATCH"),
        content = L("BACKEND.TINDER.MATCHED_WITH", {name = senderData.name}),
        thumbnail = json.decode(senderData.photos)[1]
    })
    
    return true
end)

BaseCallback("tinder:getMatches", function(source, phoneNumber)
    local matchesQuery = [[
        SELECT
        a.`name`, a.phone_number, a.photos, a.dob, a.bio, a.is_male, b.latest_message
        FROM
        phone_tinder_accounts a
        JOIN
        phone_tinder_matches b
        ON
        (b.phone_number_1 = @phoneNumber
        AND b.phone_number_2 = a.phone_number)
        OR
        (b.phone_number_2 = @phoneNumber
        AND b.phone_number_1 = a.phone_number)
        ORDER BY b.latest_message_timestamp DESC
    ]]
    
    return MySQL.query.await(matchesQuery, {["@phoneNumber"] = phoneNumber})
end)

BaseCallback("tinder:sendMessage", function(source, senderNumber, recipientNumber, content, attachments)
    if ContainsBlacklistedWord(source, "Spark", content) then
        return false
    end
    
    local senderData = MySQL.single.await("SELECT `name`, photos FROM phone_tinder_accounts WHERE phone_number = ?", {senderNumber})
    
    if not senderData then
        return true
    end
    
    local messageId = MySQL.insert.await("INSERT INTO phone_tinder_messages (sender, recipient, content, attachments) VALUES (?, ?, ?, ?)", {senderNumber, recipientNumber, content, attachments})
    
    if not messageId then
        return false
    end
    
    MySQL.update.await("UPDATE phone_tinder_matches SET latest_message = ? WHERE (phone_number_1 = ? AND phone_number_2 = ?) OR (phone_number_2 = ? AND phone_number_1 = ?)", {content, senderNumber, recipientNumber, senderNumber, recipientNumber})
    
    local recipientSource = GetSourceFromNumber(recipientNumber)
    
    if recipientSource then
        TriggerClientEvent("phone:tinder:receiveMessage", recipientSource, {
            sender = senderNumber,
            recipient = recipientNumber,
            content = content,
            attachments = attachments,
            timestamp = os.time() * 1000
        })
    end
    
    local thumbnail = attachments and json.decode(attachments)[1] or nil
    
    SendNotification(recipientNumber, {
        app = "Tinder",
        title = senderData.name,
        content = content,
        thumbnail = thumbnail,
        avatar = json.decode(senderData.photos)[1],
        showAvatar = true
    })
    
    return true
end)

BaseCallback("tinder:getMessages", function(source, phoneNumber, targetNumber, page)
    local messagesQuery = [[
        SELECT
        sender, recipient, content, attachments, timestamp
        FROM
        phone_tinder_messages
        WHERE
        (sender = @phoneNumber AND recipient = @number)
        OR
        (recipient = @phoneNumber AND sender = @number)
        ORDER BY timestamp DESC
        LIMIT @page, @perPage
    ]]
    
    local parameters = {
        ["@phoneNumber"] = phoneNumber,
        ["@number"] = targetNumber,
        ["@page"] = page * 25,
        ["@perPage"] = 25
    }
    
    return MySQL.query.await(messagesQuery, parameters)
end)

CreateThread(function()
    if not Config.AutoDisableSparkAccounts then
        return
    end
    
    local checkInterval = 360000
    local inactiveDays = 7
    
    if type(Config.AutoDisableSparkAccounts) == "number" then
        inactiveDays = math.max(Config.AutoDisableSparkAccounts, 1)
    end
    
    while not DatabaseCheckerFinished do
        Wait(500)
    end
    
    while true do
        MySQL.update("UPDATE phone_tinder_accounts SET active = 0 WHERE active = 1 AND last_seen < NOW() - INTERVAL ? DAY", {inactiveDays}, function(affectedRows)
            debugprint("Disabled", affectedRows, "inactive Spark accounts.")
        end)
        
        Wait(checkInterval)
    end
end)