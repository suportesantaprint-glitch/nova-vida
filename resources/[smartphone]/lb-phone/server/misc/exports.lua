local supportedApps = {
    twitter = true,
    instagram = true,
    tiktok = true
}

local appAliases = {
    birdy = "twitter",
    instapic = "instagram",
    trendy = "tiktok"
}

local appDisplayNames = {
    twitter = "Twitter",
    instagram = "Instagram",
    tiktok = "TikTok"
}

function ToggleVerified(appName, username, isVerified)
    assert(type(appName) == "string", "Invalid app")
    
    appName = appName:lower()
    if not supportedApps[appName] then
        appName = tostring(appAliases[appName])
    end
    
    assert(supportedApps[appName], "Invalid app")
    assert(type(username) == "string", "Invalid username")
    
    TriggerEvent("lb-phone:toggleVerified", appName, username, isVerified)
    
    local affectedRows = MySQL.Sync.execute(
        ("UPDATE phone_%s_accounts SET verified=@verified WHERE username=@username"):format(appName),
        {
            ["@username"] = username,
            ["@verified"] = isVerified
        }
    )
    
    local success = affectedRows > 0
    
    if success and isVerified and appDisplayNames[appName] then
        local loggedInUsers = MySQL.query.await(
            "SELECT phone_number FROM phone_logged_in_accounts WHERE app = ? AND username = ? AND `active` = 1",
            {appName, username}
        )
        
        for i = 1, #loggedInUsers do
            local phoneNumber = loggedInUsers[i].phone_number
            SendNotification(phoneNumber, {
                app = appDisplayNames[appName],
                title = L("BACKEND.MISC.VERIFIED")
            })
        end
    end
    
    return success
end

exports("ToggleVerified", ToggleVerified)

exports("IsVerified", function(appName, username)
    assert(type(appName) == "string", "Invalid app")
    
    appName = appName:lower()
    if not supportedApps[appName] then
        appName = tostring(appAliases[appName])
    end
    
    assert(supportedApps[appName], "Invalid app")
    assert(type(username) == "string", "Invalid username")
    
    local isVerified = MySQL.Sync.fetchScalar(
        ("SELECT verified FROM phone_%s_accounts WHERE username=@username"):format(appName),
        {["@username"] = username}
    )
    
    return isVerified or false
end)

local appUsernameFields = {
    twitter = "username",
    instagram = "username",
    tiktok = "username",
    mail = "address",
    darkchat = "username"
}

function ChangePassword(appName, username, newPassword)
    assert(type(appName) == "string", "Invalid app")
    
    appName = appName:lower()
    if not appUsernameFields[appName] then
        appName = tostring(appAliases[appName])
    end
    
    assert(appUsernameFields[appName], "Invalid app")
    assert(type(username) == "string", "Invalid username")
    assert(type(newPassword) == "string", "Invalid password")
    
    local affectedRows = MySQL.Sync.execute(
        ("UPDATE phone_%s_accounts SET password=@password WHERE %s=@username"):format(appName, appUsernameFields[appName]),
        {
            ["@username"] = username,
            ["@password"] = GetPasswordHash(newPassword)
        }
    )
    
    if affectedRows <= 0 then
        return false
    end
    
    MySQL.update(
        "DELETE FROM phone_logged_in_accounts WHERE app = ? AND username = ?",
        {appName, username}
    )
    
    return true
end

exports("ChangePassword", ChangePassword)

exports("GetEquippedPhoneNumber", function(playerIdOrIdentifier)
    if type(playerIdOrIdentifier) == "number" then
        return GetEquippedPhoneNumber(playerIdOrIdentifier)
    end
    
    local source = GetSourceFromIdentifier and GetSourceFromIdentifier(playerIdOrIdentifier)
    if source then
        return GetEquippedPhoneNumber(source)
    end
    
    local tableName = Config.Item.Unique and "phone_last_phone" or "phone_phones"
    local fieldName = "id"
    
    return MySQL.scalar.await(
        ("SELECT phone_number FROM %s WHERE %s = ?"):format(tableName, fieldName),
        {playerIdOrIdentifier}
    )
end)