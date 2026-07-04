local supportedApps = {
    Twitter = true,
    Instagram = true,
    TikTok = true,
    Mail = true,
    DarkChat = true
}

RegisterNUICallback("AccountSwitcher", function(data, callback)
    debugprint("AccountSwitcher:" .. (data.action or ""))
    
    if not currentPhone or not supportedApps[data.app] then
        debugprint("AccountSwitcher: Invalid app / no currentPhone", data.app)
        return callback(false)
    end
    
    local action = data.action
    
    if action == "switch" then
        TriggerCallback("accountSwitcher:switchAccount", callback, data.app, data.account)
    elseif action == "getAccounts" then
        TriggerCallback("accountSwitcher:getAccounts", function(accounts)
            if not accounts then
                callback(false)
                return
            end
            
            local usernames = {}
            for i = 1, #accounts do
                usernames[i] = accounts[i].username
            end
            
            callback(usernames)
        end, data.app)
    end
end)