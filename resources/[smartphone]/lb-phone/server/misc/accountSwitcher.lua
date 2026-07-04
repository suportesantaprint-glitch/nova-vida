local activeAccounts = {}
local supportedApps = {
    Twitter = true,
    Instagram = true,
    Mail = true,
    TikTok = true,
    DarkChat = true
}

local appNameMapping = {
    instapic = "Instagram",
    birdy = "Twitter",
    trendy = "TikTok",
    darkchat = "DarkChat",
    mail = "Mail"
}

for appName, isSupported in pairs(supportedApps) do
    activeAccounts[appName] = {}
end

BaseCallback("accountSwitcher:switchAccount", function(playerId, phoneNumber, appName, username)
    if not supportedApps[appName] then
        return false
    end
    
    local isLoggedIn = MySQL.scalar.await(
        "SELECT TRUE FROM phone_logged_in_accounts WHERE phone_number = ? AND app = ? AND username = ?",
        {phoneNumber, appName, username}
    )
    
    if not isLoggedIn then
        print(("Possible abuse? %s (%i) tried to switch to an account they aren't logged into."):format(
            GetPlayerName(playerId), playerId
        ))
        return false
    end
    
    local affectedRows = MySQL.update.await(
        "UPDATE phone_logged_in_accounts SET `active` = (username = ?) WHERE phone_number = ? AND app = ?",
        {username, phoneNumber, appName}
    )
    
    local success = affectedRows > 0
    if success then
        activeAccounts[appName][phoneNumber] = username
        TriggerEvent("phone:loggedInToAccount", appName, phoneNumber, username)
    end
    
    return success
end)

BaseCallback("accountSwitcher:getAccounts", function(playerId, phoneNumber, appName)
    if not supportedApps[appName] then
        return {}
    end
    
    return MySQL.query.await(
        "SELECT username FROM phone_logged_in_accounts WHERE phone_number = ? AND app = ?",
        {phoneNumber, appName}
    )
end)

function AddLoggedInAccount(phoneNumber, appName, username)
    assert(supportedApps[appName], "Invalid app: " .. appName)
    assert(type(phoneNumber) == "string", "Invalid phone number. Expected string.")
    assert(type(username) == "string", "Invalid username. Expected string.")
    
    MySQL.update.await(
        "UPDATE phone_logged_in_accounts SET `active` = 0 WHERE phone_number = ? AND app = ? AND username != ?",
        {phoneNumber, appName, username}
    )
    
    local affectedRows = MySQL.update.await(
        "INSERT INTO phone_logged_in_accounts (phone_number, app, username, active) VALUES (?, ?, ?, 1) ON DUPLICATE KEY UPDATE active = 1",
        {phoneNumber, appName, username}
    )
    
    local success = affectedRows > 0
    if success then
        activeAccounts[appName][phoneNumber] = username
        TriggerEvent("phone:loggedInToAccount", appName, phoneNumber, username)
    end
    
    return success
end

function RemoveLoggedInAccount(phoneNumber, appName, username)
    assert(supportedApps[appName], "Invalid app: " .. appName)
    assert(type(phoneNumber) == "string", "Invalid phone number. Expected string.")
    assert(type(username) == "string", "Invalid username. Expected string.")
    
    local affectedRows = MySQL.update.await(
        "DELETE FROM phone_logged_in_accounts WHERE phone_number = ? AND app = ? AND username = ?",
        {phoneNumber, appName, username}
    )
    
    local success = affectedRows > 0
    if success then
        if activeAccounts[appName][phoneNumber] == username then
            activeAccounts[appName][phoneNumber] = nil
        end
        TriggerEvent("phone:loggedOutFromAccount", appName, username, phoneNumber)
    end
    
    return success
end

function GetLoggedInAccount(phoneNumber, appName, skipCache)
    assert(supportedApps[appName], "Invalid app: " .. appName)
    assert(type(phoneNumber) == "string", "Invalid phone number. Expected string.")
    
    if activeAccounts[appName][phoneNumber] then
        return activeAccounts[appName][phoneNumber]
    end
    
    local username = MySQL.scalar.await(
        "SELECT username FROM phone_logged_in_accounts WHERE phone_number = ? AND app = ? AND active = 1",
        {phoneNumber, appName}
    )
    
    if username and not skipCache then
        debugprint("AccountSwitcher: Setting cache for " .. phoneNumber .. ", logged in as " .. username .. " on " .. appName)
        activeAccounts[appName][phoneNumber] = username
    end
    
    return username or false
end

function GetLoggedInNumbers(appName, username)
    assert(supportedApps[appName], "Invalid app: " .. appName)
    assert(type(username) == "string", "Invalid username. Expected string.")
    
    local results = MySQL.query.await(
        "SELECT phone_number FROM phone_logged_in_accounts WHERE app = ? AND username = ?",
        {appName, username}
    )
    
    if not results then
        return {}
    end
    
    local phoneNumbers = {}
    for i = 1, #results do
        phoneNumbers[#phoneNumbers + 1] = results[i].phone_number
    end
    
    return phoneNumbers
end

function GetActiveAccounts(appName)
    return activeAccounts[appName] or {}
end

function ClearActiveAccountsCache(appName, username, excludePhoneNumber)
    assert(supportedApps[appName], "Invalid app: " .. appName)
    assert(type(username) == "string", "Invalid username. Expected string.")
    
    for phoneNumber, cachedUsername in pairs(activeAccounts[appName]) do
        if cachedUsername == username and phoneNumber ~= excludePhoneNumber then
            activeAccounts[appName][phoneNumber] = nil
        end
    end
end

exports("GetSocialMediaUsername", function(phoneNumber, appKey)
    assert(type(phoneNumber) == "string", "Invalid phone number. Expected string.")
    assert(type(appKey) == "string", "Invalid app. Expected string.")
    assert(appNameMapping[appKey], "Invalid app: " .. appKey)
    
    return GetLoggedInAccount(phoneNumber, appNameMapping[appKey], true)
end)

AddEventHandler("playerDropped", function()
    local phoneNumber = GetEquippedPhoneNumber(source)
    if not phoneNumber then
        return
    end
    
    for appName, accounts in pairs(activeAccounts) do
        if accounts[phoneNumber] then
            accounts[phoneNumber] = nil
            debugprint("AccountSwitcher: Player dropped, logging out " .. phoneNumber .. " from " .. appName)
        end
    end
end)