InExportCall = false
local isVideoCall = false
local currentCallId = nil
local isInCustomCall = false
local customCallData = nil
local callStartTime = 0
local callAnswered = false
local customNumbers = {}

local function endCustomCall()
    debugprint("EndCustomCall triggered")
    
    if customCallData then
        local callDuration = math.floor((GetGameTimer() - callStartTime) / 1000 + 0.5)
        debugprint("Custom call to", customCallData.number, "ended after", callDuration, "seconds", "answered:", callAnswered)
        TriggerServerEvent("phone:logCall", customCallData.number, callDuration)
    end
    
    isInCustomCall = false
    customCallData = nil
    currentCallId = nil
    callStartTime = 0
    callAnswered = false
    
    SetPhoneAction("default")
    SendReactMessage("call:endCall")
    
    if not phoneOpen then
        PlayCloseAnim()
    end
end

local function startCustomCall(phoneNumber)
    local numberData = customNumbers[phoneNumber]
    if not numberData then
        return false
    end
    
    local callId = "CUSTOM_NUMBER_" .. math.random(9999)
    isInCustomCall = true
    currentCallId = callId
    customCallData = numberData
    callStartTime = GetGameTimer()
    callAnswered = false
    
    Citizen.CreateThreadNow(function()
        numberData.onCall({
            id = callId,
            accept = function()
                if not callAnswered and currentCallId == callId then
                    callAnswered = true
                    SetPhoneAction("call")
                    SendReactMessage("call:connected")
                end
            end,
            deny = function()
                if currentCallId == callId then
                    endCustomCall()
                end
            end,
            setName = function(name)
                if currentCallId == callId then
                    SendReactMessage("call:setContactData", {name = name})
                end
            end,
            hasEnded = function()
                return currentCallId ~= callId
            end
        })
    end)
    
    return true
end

local function handleCustomCallAction(action)
    if not customCallData then
        return
    end
    
    if action == "end" then
        if customCallData.onEnd then
            Citizen.CreateThreadNow(customCallData.onEnd)
        end
        endCustomCall()
        return
    end
    
    if action:find("keypad_") then
        if not customCallData.onKeypad then
            return
        end
        
        local key = action:sub(8)
        if not key then
            return
        end
        
        Citizen.CreateThreadNow(function()
            customCallData.onKeypad(key)
        end)
        return
    end
    
    if customCallData.onAction then
        customCallData.onAction(action)
    end
end

RegisterNUICallback("Phone", function(data, callback)
    if not currentPhone then
        return
    end
    
    local action = data.action
    debugprint("Phone:" .. (action or ""))
    
    if action == "getContacts" then
        TriggerCallback("getContacts", function(contacts)
            if Config.Companies.Enabled then
                for companyName, companyData in pairs(Config.Companies.Contacts) do
                    table.insert(contacts, {
                        firstname = companyData.name,
                        avatar = companyData.photo,
                        company = companyName
                    })
                end
            end
            callback(contacts)
        end)
    elseif action == "toggleFavourite" then
        TriggerCallback("toggleFavourite", callback, data.number, data.favourite)
    elseif action == "toggleBlock" then
        TriggerCallback("toggleBlock", callback, data.number, data.blocked)
    elseif action == "removeContact" then
        TriggerCallback("removeContact", callback, data.number)
    elseif action == "updateContact" then
        TriggerCallback("updateContact", callback, data.data)
    elseif action == "saveContact" then
        TriggerCallback("saveContact", callback, data.data)
    elseif action == "getRecent" then
        TriggerCallback("getRecentCalls", callback, data.missed == true, data.lastId)
    elseif action == "getBlockedNumbers" then
        TriggerCallback("getBlockedNumbers", function(blockedNumbers)
            local numbers = {}
            for i, numberData in pairs(blockedNumbers) do
                numbers[i] = numberData.number
            end
            callback(numbers)
        end)
    elseif action == "toggleMute" then
        if not currentCallId then
            return callback(false)
        elseif customCallData then
            handleCustomCallAction(data.toggle and "mute" or "unmute")
            return callback(data.toggle)
        end
        
        if data.toggle then
            RemoveFromCall(currentCallId)
        else
            AddToCall(currentCallId)
        end
        
        TriggerServerEvent("phone:phone:toggleMute", data.toggle)
        callback(data.toggle)
    elseif action == "toggleSpeaker" then
        if not currentCallId then
            return callback(false)
        elseif customCallData then
            handleCustomCallAction(data.toggle and "enable_speaker" or "disable_speaker")
            return callback(data.toggle)
        end
        
        TriggerServerEvent("phone:phone:toggleSpeaker", data.toggle)
        ToggleSpeaker(data.toggle)
        callback(data.toggle)
    elseif action == "sendVoicemail" then
        TriggerCallback("sendVoicemail", callback, data.data)
    elseif action == "getVoiceMails" then
        TriggerCallback("getRecentVoicemails", callback, data.page)
    elseif action == "deleteVoiceMail" then
        TriggerCallback("deleteVoiceMail", callback, data.id)
    elseif action == "keypad" then
        callback("ok")
        if customCallData then
            handleCustomCallAction("keypad_" .. data.key)
        end
    end
    
    if action == "call" then
        if startCustomCall(data.number) then
            return callback("CUSTOM_NUMBER")
        end
        
        if data.company then
            if not Config.Companies.Enabled or data.videoCall then
                return
            end
            
            local companyData = Config.Companies.Contacts[data.company]
            if not companyData then
                local isValidService = false
                for i = 1, #Config.Companies.Services do
                    if Config.Companies.Services[i].job == data.company then
                        isValidService = true
                        break
                    end
                end
                if not isValidService then
                    return
                end
            end
        end
        
        isVideoCall = data.videoCall
        TriggerCallback("call", callback, data)
    elseif action == "answerCall" then
        if IsInCall() then
            debugprint("answerCall: Already in call")
            return
        end
        
        if IsLive() then
            debugprint("answerCall: Ending live")
            TriggerCallback("instagram:endLive")
        elseif IsWatchingLive() then
            debugprint("answerCall: Leaving live")
            SendReactMessage("instagram:liveEnded", IsWatchingLive())
        end
        
        debugprint("Answering call", data.callId)
        TriggerCallback("answerCall", callback, data.callId)
        callback("ok")
    elseif action == "endCall" then
        EndCall()
        callback("ok")
    elseif action == "flipCamera" then
        ToggleSelfieCam(not IsSelfieCam())
    elseif action == "requestVideoCall" then
        TriggerCallback("requestVideoCall", callback, data.callId, data.peerId)
    elseif action == "answerVideoRequest" then
        TriggerCallback("answerVideoRequest", callback, data.callId, data.accept)
        if data.accept then
            isVideoCall = true
            EnableWalkableCam()
        end
    elseif action == "stopVideoCall" then
        TriggerCallback("stopVideoCall", callback, data.callId)
    end
end)

function EndCall()
    TriggerServerEvent("phone:endCall")
    if customCallData then
        handleCustomCallAction("end")
    end
end

RegisterNetEvent("phone:phone:setCall", function(callData)
    if not HasPhoneItem(currentPhone) then
        debugprint("no phone, not showing call")
        return
    end
    
    if phoneDisabled then
        debugprint("phone is disabled, not showing call")
        return
    end
    
    if customCallData or isInCustomCall then
        debugprint("in a (custom?) call", tostring(customCallData), tostring(isInCustomCall))
        return
    end
    
    if IsPedDeadOrDying(PlayerPedId(), false) then
        debugprint("player is dead, not showing call")
        return
    elseif CanOpenPhone and not CanOpenPhone() then
        debugprint("can't open phone, not showing call")
        return
    end
    
    isVideoCall = callData.videoCall
    SendReactMessage("incomingCall", callData)
end)

RegisterNetEvent("phone:phone:enableExportCall", function()
    InExportCall = true
end)

RegisterNetEvent("phone:phone:connectCall", function(callId, isSilent)
    debugprint("phone:phone:connectCall", callId, isSilent)
    isInCustomCall = true
    currentCallId = callId
    AddToCall(callId)
    
    if isSilent then
        return
    end
    
    SetPhoneAction("call")
    SendReactMessage("call:connected")
    
    if isVideoCall then
        EnableWalkableCam()
    end
end)

RegisterNetEvent("phone:phone:endCall", function()
    debugprint("phone:phone:endCall")
    local wasInCall = isInCustomCall
    isInCustomCall = false
    isVideoCall = false
    
    SetPhoneAction("default")
    DisableWalkableCam()
    
    if not phoneOpen and wasInCall then
        debugprint("close anim")
        PlayCloseAnim()
    end
    
    RemoveFromCall(currentCallId)
    currentCallId = nil
    InExportCall = false
    SendReactMessage("call:endCall")
end)

RegisterNetEvent("phone:phone:userUnavailable", function()
    debugprint("phone:phone:userUnavailable")
    SendReactMessage("call:userUnavailable")
end)

RegisterNetEvent("phone:phone:userBusy", function()
    debugprint("phone:phone:userBusy")
    SendReactMessage("call:userBusy")
end)

function IsInCall()
    return isInCustomCall
end

exports("IsInCall", IsInCall)

exports("AddContact", function(contact)
    assert(type(contact) == "table", "contact must be a table")
    assert(type(contact.number) == "string", "contact.number must be a string")
    assert(type(contact.firstname) == "string", "contact.firstname must be a string")
    
    local success = AwaitCallback("saveContact", contact)
    if success then
        SendReactMessage("phone:contactAdded", contact)
    end
    return success
end)

RegisterNetEvent("phone:phone:videoRequested", function(data)
    debugprint("phone:phone:videoRequested", data)
    SendReactMessage("call:videoRequested", data)
end)

RegisterNetEvent("phone:phone:videoRequestAnswered", function(accepted)
    debugprint("phone:phone:videoRequestAnswered", accepted)
    SendReactMessage("call:videoRequestAnswered", accepted)
    if accepted then
        isVideoCall = true
        EnableWalkableCam()
    end
end)

RegisterNetEvent("phone:phone:stopVideoCall", function()
    debugprint("phone:phone:stopVideoCall")
    SendReactMessage("call:stopVideoCall")
    isVideoCall = false
    DisableWalkableCam()
end)

RegisterNetEvent("phone:phone:contactAdded", function(contact)
    debugprint("phone:phone:contactAdded", contact)
    SendReactMessage("phone:contactAdded", contact)
end)

function CreateCall(options)
    assert(type(options) == "table", "options must be a table")
    assert(options.number or options.company, "options must contain either a number or company")
    
    if not currentPhone then
        return debugprint("no phone")
    end
    
    if options.company then
        if not Config.Companies.Enabled then
            return debugprint("company calls are disabled in config")
        end
        
        local isValidCompany = false
        local companyLabel = options.company
        local companyData = Config.Companies.Contacts[options.company]
        
        if companyData then
            companyLabel = companyData.name
            isValidCompany = true
        else
            for i = 1, #Config.Companies.Services do
                local service = Config.Companies.Services[i]
                if service.job == options.company then
                    isValidCompany = true
                    companyLabel = service.name
                    break
                end
            end
        end
        
        if not isValidCompany then
            return debugprint("invalid company")
        end
        
        debugprint("CreateCall: company", options)
        SendReactMessage("call", {
            company = options.company,
            companylabel = companyLabel,
            hideCallerId = options.hideNumber == true
        })
    else
        debugprint("CreateCall: number", options)
        SendReactMessage("call", {
            number = options.number,
            videoCall = options.videoCall == true,
            hideCallerId = options.hideNumber == true
        })
    end
end

exports("CreateCall", CreateCall)

exports("CreateCustomNumber", function(number, data)
    local resource = GetInvokingResource()
    assert(type(number) == "string", "number must be a string")
    assert(type(data) == "table", "data must be a table")
    assert(type(data.onCall) == "function", "data.onCall must be a function")
    
    if customNumbers[number] then
        return false, "Number already exists"
    end
    
    customNumbers[number] = {
        resource = resource,
        number = number,
        onCall = data.onCall,
        onEnd = data.onEnd,
        onAction = data.onAction,
        onKeypad = data.onKeypad
    }
    
    return true
end)

exports("RemoveCustomNumber", function(number)
    local resource = GetInvokingResource()
    assert(type(number) == "string", "number must be a string")
    
    local numberData = customNumbers[number]
    if not numberData then
        return false, "Number does not exist"
    end
    
    if numberData.resource ~= resource then
        return false, "Number was not created by " .. resource
    end
    
    customNumbers[number] = nil
    return true
end)

exports("EndCustomCall", function()
    if customCallData then
        endCustomCall()
        return true
    end
    return false
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        return
    end
    
    for number, numberData in pairs(customNumbers) do
        if numberData.resource == resourceName then
            debugprint("Removed custom number", number, "due to resource stopping")
            if customCallData == numberData then
                handleCustomCallAction("end")
            end
            customNumbers[number] = nil
        end
    end
end)