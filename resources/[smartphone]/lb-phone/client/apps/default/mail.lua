local currentMail = nil

local function processMailData(mailData)
    if not mailData then
        return false
    end
    
    mailData.attachments = mailData.attachments and json.decode(mailData.attachments) or {}
    mailData.actions = mailData.actions and json.decode(mailData.actions) or {}
    
    return mailData
end

RegisterNUICallback("Mail", function(data, callback)
    local action = data.action
    debugprint("Mail:" .. (action or ""))
    
    if action == "isLoggedIn" then
        TriggerCallback("mail:isLoggedIn", callback)
    elseif action == "createMail" then
        TriggerCallback("mail:createAccount", callback, data.data.email, data.data.password)
    elseif action == "changePassword" then
        TriggerCallback("mail:changePassword", callback, data.oldPassword, data.newPassword)
    elseif action == "deleteAccount" then
        TriggerCallback("mail:deleteAccount", callback, data.password)
    elseif action == "login" then
        TriggerCallback("mail:login", callback, data.data.email, data.data.password)
    elseif action == "logout" then
        TriggerCallback("mail:logout", callback)
    elseif action == "getMails" then
        TriggerCallback("mail:getMails", callback, {lastId = data.lastId})
    elseif action == "getMail" then
        TriggerCallback("mail:getMail", function(mailData)
            currentMail = processMailData(mailData)
            callback(currentMail)
        end, data.id)
    elseif action == "search" then
        TriggerCallback("mail:getMails", callback, {search = data.query, lastId = data.lastId})
    elseif action == "sendMail" then
        TriggerCallback("mail:sendMail", callback, data.data)
    elseif action == "deleteMail" then
        TriggerCallback("mail:deleteMail", callback, data.id)
    elseif action == "action" then
        if currentMail.id ~= data.id then
            return debugprint("wrong mail id for action")
        end
        
        local actionIndex = (data.actionId or 0) + 1
        local actionData = currentMail.actions[actionIndex]
        
        if not actionData then
            return debugprint("no action found", actionIndex)
        end
        
        if actionData.data and actionData.data.qbMail then
            TriggerEvent(actionData.event, actionData.data.data)
            return callback("ok")
        end
        
        if actionData.isServer then
            TriggerServerEvent(actionData.event, data.id, actionData.data)
        else
            TriggerEvent(actionData.event, data.id, actionData.data)
        end
        
        callback("ok")
    end
end)

RegisterNetEvent("phone:mail:newMail", function(mailData)
    SendReactMessage("mail:newMail", mailData)
end)

RegisterNetEvent("phone:mail:mailDeleted", function(mailId)
    SendReactMessage("mail:deleteMail", mailId)
end)