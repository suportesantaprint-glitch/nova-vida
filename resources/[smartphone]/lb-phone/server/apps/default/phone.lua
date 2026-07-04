local disabledCompanyCalls = {}

local activeCalls = {}

function GetContact(callerNumber, contactNumber, callback)
    local queryParams = {callerNumber, contactNumber, callerNumber}
    local query = [[
        SELECT
            CONCAT(firstname, ' ', lastname) AS `name`, 
            profile_image AS avatar, 
            firstname, 
            lastname, 
            email, 
            address, 
            contact_phone_number AS `number`, 
            favourite,
            (IF((SELECT TRUE FROM phone_phone_blocked_numbers b WHERE b.phone_number=? AND b.blocked_number=`number`), TRUE, FALSE)) AS blocked
        FROM phone_phone_contacts
        WHERE contact_phone_number=? AND phone_number=?
    ]]
    
    if callback then
        return MySQL.single(query, queryParams, callback)
    else
        return MySQL.single.await(query, queryParams)
    end
end

function CreateContact(phoneNumber, contactData)
    local success = MySQL.Sync.execute([[
        INSERT INTO phone_phone_contacts (contact_phone_number, firstname, lastname, profile_image, email, address, phone_number)
        VALUES (@contactNumber, @firstname, @lastname, @avatar, @email, @address, @phoneNumber)
        ON DUPLICATE KEY UPDATE firstname=@firstname, lastname=@lastname, profile_image=@avatar, email=@email, address=@address
    ]], {
        ["@contactNumber"] = contactData.number,
        ["@firstname"] = contactData.firstname,
        ["@lastname"] = contactData.lastname or "",
        ["@avatar"] = contactData.avatar,
        ["@email"] = contactData.email,
        ["@address"] = contactData.address,
        ["@phoneNumber"] = phoneNumber
    })
    
    return success > 0
end

BaseCallback("saveContact", function(source, phoneNumber, contactData)
    return CreateContact(phoneNumber, contactData)
end, false)

BaseCallback("getContacts", function(source, phoneNumber)
    return MySQL.query.await([[
        SELECT 
            contact_phone_number AS number, 
            firstname, 
            lastname, 
            profile_image AS avatar, 
            favourite,
            (IF((SELECT TRUE FROM phone_phone_blocked_numbers b WHERE b.phone_number=@phoneNumber AND b.blocked_number=`number`), TRUE, FALSE)) AS blocked
        FROM phone_phone_contacts c
        WHERE c.phone_number=@phoneNumber
    ]], {
        ["@phoneNumber"] = phoneNumber
    })
end, {})

BaseCallback("toggleBlock", function(source, phoneNumber, contactNumber, shouldBlock)
    local query = shouldBlock and 
        "INSERT INTO phone_phone_blocked_numbers (phone_number, blocked_number) VALUES (@phoneNumber, @number) ON DUPLICATE KEY UPDATE phone_number=@phoneNumber" or
        "DELETE FROM phone_phone_blocked_numbers WHERE phone_number=@phoneNumber AND blocked_number=@number"
    
    MySQL.update.await(query, {
        ["@phoneNumber"] = phoneNumber,
        ["@number"] = contactNumber
    })
    
    return shouldBlock
end, false)

BaseCallback("toggleFavourite", function(source, phoneNumber, contactNumber, isFavourite)
    MySQL.update.await(
        "UPDATE phone_phone_contacts SET favourite=@favourite WHERE contact_phone_number=@number AND phone_number=@phoneNumber",
        {
            ["@phoneNumber"] = phoneNumber,
            ["@number"] = contactNumber,
            ["@favourite"] = isFavourite == true
        }
    )
    return true
end, false)

BaseCallback("removeContact", function(source, phoneNumber, contactNumber)
    MySQL.update.await(
        "DELETE FROM phone_phone_contacts WHERE contact_phone_number=? AND phone_number=?",
        {contactNumber, phoneNumber}
    )
    return true
end, false)

BaseCallback("updateContact", function(source, phoneNumber, contactData)
    MySQL.update.await([[
        UPDATE phone_phone_contacts 
        SET firstname=@firstname, lastname=@lastname, profile_image=@avatar, email=@email, address=@address, contact_phone_number=@newNumber 
        WHERE contact_phone_number=@number AND phone_number=@phoneNumber
    ]], {
        ["@phoneNumber"] = phoneNumber,
        ["@number"] = contactData.oldNumber,
        ["@newNumber"] = contactData.number,
        ["@firstname"] = contactData.firstname,
        ["@lastname"] = contactData.lastname or "",
        ["@avatar"] = contactData.avatar,
        ["@email"] = contactData.email,
        ["@address"] = contactData.address
    })
    return true
end, false)

BaseCallback("getRecentCalls", function(source, phoneNumber, missedOnly, lastCallId)
    missedOnly = missedOnly == true
    local queryParams = {phoneNumber, phoneNumber, phoneNumber, phoneNumber, phoneNumber}
    
    local query = [[
        SELECT
            c.id,
            c.duration,
            c.answered,
            c.caller = ? AS called,
            IF(c.callee = ?, c.caller, c.callee) AS `number`,
            IF(c.callee = ?, c.hide_caller_id, FALSE) AS hideCallerId,
            (EXISTS (SELECT 1 FROM phone_phone_blocked_numbers b WHERE b.phone_number=? AND b.blocked_number=`number`)) AS blocked,
            c.`timestamp`
        FROM phone_phone_calls c
        WHERE (c.callee = ? {MISSED_CALLS_CONDITION}) {PAGINATION}
        ORDER BY c.id DESC
        LIMIT 25
    ]]
    
    if missedOnly then
        query = query:gsub("{MISSED_CALLS_CONDITION}", "AND c.answered = 0")
    else
        query = query:gsub("{MISSED_CALLS_CONDITION}", "OR c.caller = ?")
        queryParams[#queryParams + 1] = phoneNumber
    end
    
    if lastCallId then
        query = query:gsub("{PAGINATION}", "AND c.id < ?")
        queryParams[#queryParams + 1] = lastCallId
    else
        query = query:gsub("{PAGINATION}", "")
    end
    
    local calls = MySQL.query.await(query, queryParams)
    
    for i = 1, #calls do
        local call = calls[i]
        call.hideCallerId = call.hideCallerId == true
        call.blocked = call.blocked == true
        call.called = call.called == true
        
        if call.hideCallerId then
            call.number = L("BACKEND.CALLS.NO_CALLER_ID")
        end
    end
    
    return calls
end, {})

BaseCallback("getBlockedNumbers", function(source, phoneNumber)
    return MySQL.query.await(
        "SELECT blocked_number AS `number` FROM phone_phone_blocked_numbers WHERE phone_number=?",
        {phoneNumber}
    )
end, {})

local function logCall(callerNumber, calleeNumber, duration, wasAnswered, hideCallerId, callerSource)
    MySQL.insert(
        "INSERT INTO phone_phone_calls (caller, callee, duration, answered, hide_caller_id) VALUES (@caller, @callee, @duration, @answered, @hideCallerId)",
        {
            ["@caller"] = callerNumber,
            ["@callee"] = calleeNumber,
            ["@duration"] = duration,
            ["@answered"] = wasAnswered,
            ["@hideCallerId"] = hideCallerId
        }
    )
    
    if not wasAnswered and callerSource ~= calleeNumber then
        local phoneExists = MySQL.scalar.await(
            "SELECT TRUE FROM phone_phones WHERE phone_number = ?",
            {calleeNumber}
        )
        
        if not phoneExists then
            return
        end
        
        if hideCallerId then
            SendNotification(calleeNumber, {
                app = "Phone",
                title = L("BACKEND.CALLS.NO_CALLER_ID"),
                content = L("BACKEND.CALLS.MISSED_CALL"),
                showAvatar = false
            })
            return
        end
        
        GetContact(callerNumber, calleeNumber, function(contact)
            SendNotification(calleeNumber, {
                app = "Phone",
                title = contact and contact.name or callerNumber,
                content = L("BACKEND.CALLS.MISSED_CALL"),
                avatar = contact and contact.avatar,
                showAvatar = true
            })
        end)
        
        SendMessage(callerNumber, calleeNumber, "<!CALL-NO-ANSWER!>")
    end
end

RegisterNetEvent("phone:logCall", function(calleeNumber, duration, wasAnswered)
    local playerId = source
    local callerNumber = GetEquippedPhoneNumber(playerId)
    
    if not (callerNumber and calleeNumber) or not duration then
        return
    end
    
    logCall(callerNumber, calleeNumber, duration, wasAnswered, false, callerNumber)
end)

local function generateCallId()
    local callId = math.random(9999)
    while activeCalls[callId] do
        callId = math.random(9999)
    end
    return callId
end

local function isPlayerInCall(playerId)
    for callId, callData in pairs(activeCalls) do
        local callerSource = callData.caller and callData.caller.source
        local calleeSource = callData.callee and callData.callee.source
        
        if callerSource == playerId or calleeSource == playerId then
            return true, callId
        end
    end
    return false
end

RegisterNetEvent("phone:phone:disableCompanyCalls", function(disable)
    local playerId = source
    if disable then
        disabledCompanyCalls[playerId] = true
    else
        disabledCompanyCalls[playerId] = nil
    end
end)

BaseCallback("call", function(source, callerNumber, callOptions)
    debugprint("phone:phone:call", source, callerNumber, callOptions)
    
    if isPlayerInCall(source) then
        debugprint(source, "is in call, returning")
        return false
    end
    
    local callId = generateCallId()
    local callData = {
        started = os.time(),
        answered = false,
        videoCall = callOptions.videoCall == true,
        hideCallerId = callOptions.hideCallerId == true,
        callId = callId,
        caller = {
            source = source,
            number = callerNumber,
            nearby = {}
        }
    }
    
    if callOptions.company then
        if not Config.Companies.Enabled or callOptions.videoCall then
            debugprint("company calls are disabled in config or trying to call with video")
            TriggerClientEvent("phone:phone:userBusy", source)
            return false
        end
        
        local companyExists = Config.Companies.Contacts[callOptions.company]
        if not companyExists then
            local serviceExists = false
            for i = 1, #Config.Companies.Services do
                if Config.Companies.Services[i].job == callOptions.company then
                    serviceExists = true
                    break
                end
            end
            if not serviceExists then
                debugprint("invalid company (does not exist in Config.Companies.Contacts or Config.Companies.Services)")
                return false
            end
        end
        
        if not Config.Companies.AllowAnonymous then
            callData.hideCallerId = false
        end
        
        callData.videoCall = false
        callData.company = callOptions.company
        callData.callee = {nearby = {}}
        
        local employees = GetEmployees(callOptions.company)
        debugprint("GetEmployees result:", employees)
        
        for i = 1, #employees do
            local employeeId = employees[i]
            if not isPlayerInCall(employeeId) and employeeId ~= source and not disabledCompanyCalls[employeeId] then
                TriggerClientEvent("phone:phone:setCall", employeeId, {
                    callId = callId,
                    number = callerNumber,
                    company = callOptions.company,
                    companylabel = callOptions.companylabel,
                    hideCallerId = callData.hideCallerId
                })
            else
                debugprint("employee", employeeId, "is in call or have disabled company calls")
            end
        end
    else
        local isBlocked = MySQL.Sync.fetchScalar([[
            SELECT TRUE FROM phone_phone_blocked_numbers WHERE
            (phone_number = @number1 AND blocked_number = @number2)
            OR (phone_number = @number2 AND blocked_number = @number1)
        ]], {
            ["@number1"] = callerNumber,
            ["@number2"] = callOptions.number
        })
        
        if isBlocked then
            debugprint(source, "tried to call", callOptions.number, "but they are blocked")
            TriggerClientEvent("phone:phone:userBusy", source)
            return false
        end
        
        if callOptions.number == callerNumber then
            debugprint(source, "tried to call themselves")
            TriggerClientEvent("phone:phone:userBusy", source)
            return false
        end
        
        local calleeSource = GetSourceFromNumber(callOptions.number)
        local calleeInCall = calleeSource and isPlayerInCall(calleeSource)
        
        if not calleeSource or calleeInCall or IsPhoneDead(callOptions.number) or HasAirplaneMode(callOptions.number) then
            logCall(callerNumber, callOptions.number, 0, false, callOptions.hideCallerId)
            
            if calleeInCall then
                debugprint(source, "tried to call", callOptions.number, "but they are in call")
                TriggerClientEvent("phone:phone:userBusy", source)
            else
                debugprint(source, "tried to call", callOptions.number, "but they are not online / their phone is dead")
                TriggerClientEvent("phone:phone:userUnavailable", source)
            end
            return false
        end
        
        callData.callee = {
            source = calleeSource,
            number = callOptions.number,
            nearby = {}
        }
        
        debugprint(source, "is calling", callOptions.number, "with callId", callId)
        
        TriggerClientEvent("phone:phone:setCall", calleeSource, {
            callId = callId,
            number = callerNumber,
            videoCall = callOptions.videoCall,
            webRTC = callOptions.webRTC,
            hideCallerId = callOptions.hideCallerId
        })
    end
    
    activeCalls[callId] = callData
    TriggerEvent("lb-phone:newCall", callData)
    
    return callId
end)

RegisterLegacyCallback("answerCall", function(source, callback, callId)
    debugprint("phone:phone:answerCall", source, callId)
    
    local callData = activeCalls[callId]
    if not callData then
        debugprint("phone:phone:answerCall: invalid call id")
        return callback(false)
    end
    
    if callData.company then
        if callData.callee.source then
            return callback(false)
        end
        
        local employees = GetEmployees(callData.company)
        for i = 1, #employees do
            local employeeId = employees[i]
            if not isPlayerInCall(employeeId) and employeeId ~= source and not disabledCompanyCalls[employeeId] then
                TriggerClientEvent("phone:phone:endCall", employeeId, callId)
            end
        end
        
        callData.callee.source = source
    else
        if callData.callee.source ~= source then
            debugprint("phone:phone:answerCall: invalid source")
            return callback(false)
        end
    end
    
    local callerSource = callData.caller.source
    local calleeSource = callData.callee.source
    
    local callerState = Player(callerSource).state
    local calleeState = Player(calleeSource).state
    
    callerState.speakerphone = false
    calleeState.speakerphone = false
    callerState.mutedCall = false
    calleeState.mutedCall = false
    callerState.otherMutedCall = false
    calleeState.otherMutedCall = false
    callerState.onCallWith = calleeSource
    calleeState.onCallWith = callerSource
    callerState.callAnswered = true
    calleeState.callAnswered = true
    
    callData.answered = true
    
    TriggerClientEvent("phone:phone:connectCall", source, callId)
    TriggerClientEvent("phone:phone:connectCall", callData.caller.source, callId, callData.exportCall == true)
    
    TriggerClientEvent("phone:phone:setCallEffect", source, callData.caller.source, true)
    TriggerClientEvent("phone:phone:setCallEffect", callData.caller.source, source, true)
    
    TriggerEvent("lb-phone:callAnswered", callData)
    debugprint("phone:phone:answerCall: answered call", callId)
    
    callback(true)
end)

BaseCallback("requestVideoCall", function(source, phoneNumber, callId, enable)
    if not callId or not activeCalls[callId] then
        debugprint("requestVideoCall: invalid call id", callId, json.encode(activeCalls, {indent = true}))
        return false
    end
    
    debugprint("requestVideoCall", source, callId, enable)
    
    local callData = activeCalls[callId]
    if callData.videoCall or not callData.answered then
        return false
    end
    
    local otherSource = callData.caller.source == source and callData.callee.source or callData.caller.source
    callData.videoRequested = true
    
    TriggerClientEvent("phone:phone:videoRequested", otherSource, enable)
end)

BaseCallback("answerVideoRequest", function(source, phoneNumber, callId, accept)
    if not callId or not activeCalls[callId] then
        debugprint("answerVideoRequest: invalid call id")
        return false
    end
    
    debugprint("answerVideoRequest", source, callId, accept)
    
    local callData = activeCalls[callId]
    local otherSource = callData.caller.source == source and callData.callee.source or callData.caller.source
    
    if callData.videoCall or not callData.answered or not callData.videoRequested then
        return false
    end
    
    callData.videoRequested = false
    callData.videoCall = accept == true
    
    TriggerClientEvent("phone:phone:videoRequestAnswered", otherSource, accept)
    return true
end)

BaseCallback("stopVideoCall", function(source, phoneNumber, callId)
    if not callId or not activeCalls[callId] then
        debugprint("stopVideoCall: invalid call id")
        return false
    end
    
    local callData = activeCalls[callId]
    local otherSource = callData.caller.source == source and callData.callee.source or callData.caller.source
    
    if not callData.videoCall or not callData.answered then
        return false
    end
    
    callData.videoCall = false
    
    TriggerClientEvent("phone:phone:stopVideoCall", source)
    TriggerClientEvent("phone:phone:stopVideoCall", otherSource)
    
    return true
end)

local function endCall(playerId, callback)
    local inCall, callId = isPlayerInCall(playerId)
    debugprint("^5EndCall^7:", playerId, inCall, callId)
    
    if not inCall or not callId or not activeCalls[callId] then
        if callback then
            callback(false)
        end
        debugprint("^5EndCall^7: not in call/invalid callId")
        return false
    end
    
    local callData = activeCalls[callId]
    local callerSource = callData.caller.source
    local calleeSource = callData.callee.source
    
    if calleeSource then
        debugprint("^5EndCall^7: ending call for callee", callId, calleeSource)
        TriggerClientEvent("phone:phone:endCall", calleeSource)
        TriggerClientEvent("phone:phone:removeVoiceTarget", -1, calleeSource, true)
        TriggerClientEvent("phone:phone:removeVoiceTarget", -1, callerSource, true)
        TriggerClientEvent("phone:phone:setCallEffect", calleeSource, callerSource, false)
        TriggerClientEvent("phone:phone:setCallEffect", callerSource, calleeSource, false)
    else
        if callData.company then
            local employees = GetEmployees(callData.company)
            for i = 1, #employees do
                local employeeId = employees[i]
                if not isPlayerInCall(employeeId) and not disabledCompanyCalls[employeeId] then
                    TriggerClientEvent("phone:phone:endCall", employeeId, callId)
                end
            end
        end
    end
    
    if callerSource then
        debugprint("^5EndCall^7: ending call for caller", callId, callerSource)
        TriggerClientEvent("phone:phone:endCall", callerSource)
    end
    
    if callerSource and Player(callerSource) then
        local callerState = Player(callerSource).state
        callerState.onCallWith = nil
        callerState.speakerphone = false
        callerState.mutedCall = false
        callerState.otherMutedCall = false
        callerState.callAnswered = false
    end
    
    if calleeSource and Player(calleeSource) then
        local calleeState = Player(calleeSource).state
        calleeState.onCallWith = nil
        calleeState.speakerphone = false
        calleeState.mutedCall = false
        calleeState.otherMutedCall = false
        calleeState.callAnswered = false
    end
    
    local callerNearby = callData.caller.nearby
    local calleeNearby = callData.callee.nearby
    
    if callerNearby and calleeSource then
        for i = 1, #callerNearby do
            TriggerClientEvent("phone:phone:removeVoiceTarget", calleeSource, callerNearby[i], true)
            TriggerClientEvent("phone:phone:removeVoiceTarget", callerNearby[i], calleeSource, true)
        end
    end
    
    if calleeNearby and callerSource then
        for i = 1, #calleeNearby do
            TriggerClientEvent("phone:phone:removeVoiceTarget", callerSource, calleeNearby[i], true)
            TriggerClientEvent("phone:phone:removeVoiceTarget", calleeNearby[i], callerSource, true)
        end
    end
    
    if not callData.company then
        logCall(
            callData.caller.number,
            callData.callee.number,
            os.time() - callData.started,
            callData.answered,
            callData.hideCallerId,
            GetEquippedPhoneNumber(playerId)
        )
    end
    
    TriggerEvent("lb-phone:callEnded", callData)
    
    Log("Calls", callData.caller.source, "info",
        L("BACKEND.LOGS.CALL_ENDED"),
        L("BACKEND.LOGS.CALL_DESCRIPTION", {
            duration = os.time() - callData.started,
            caller = FormatNumber(callData.caller.number),
            callee = callData.callee.number and FormatNumber(callData.callee.number) or callData.company,
            answered = callData.answered
        })
    )
    
    activeCalls[callId] = nil
    
    if callback then
        callback(true)
    end
    
    return true
end

RegisterNetEvent("phone:endCall", function()
    endCall(source)
end)

BaseCallback("getRecentVoicemails", function(source, phoneNumber, page)
    return MySQL.query.await([[
        SELECT id, IF(hide_caller_id, null, caller) AS `number`, url, duration, hide_caller_id AS hideCallerId, `timestamp`
        FROM phone_phone_voicemail
        WHERE callee = ?
        ORDER BY `timestamp` DESC
        LIMIT ?, ?
    ]], {
        phoneNumber,
        (page or 0) * 25,
        25
    })
end, {})

BaseCallback("deleteVoiceMail", function(source, phoneNumber, voicemailId)
    local affectedRows = MySQL.update.await(
        "DELETE FROM phone_phone_voicemail WHERE id = ? AND callee = ?",
        {voicemailId, phoneNumber}
    )
    return affectedRows > 0
end)

BaseCallback("sendVoicemail", function(source, callerNumber, voicemailData)
    MySQL.insert.await(
        "INSERT INTO phone_phone_voicemail (caller, callee, url, duration, hide_caller_id) VALUES (@caller, @callee, @url, @duration, @hideCallerId)",
        {
            ["@caller"] = callerNumber,
            ["@callee"] = voicemailData.number,
            ["@url"] = voicemailData.src,
            ["@duration"] = voicemailData.duration,
            ["@hideCallerId"] = voicemailData.hideCallerId == true
        }
    )
    
    SendNotification(voicemailData.number, {
        app = "Phone",
        title = L("BACKEND.CALLS.NEW_VOICEMAIL")
    })
    
    return true
end)

function HasAirplaneMode(phoneNumber)
    debugprint("checking if", phoneNumber, "has airplane mode enabled")
    
    local settings = GetSettings(phoneNumber)
    if not settings then
        debugprint("no settings found for", phoneNumber)
        return
    end
    
    return settings.airplaneMode
end

exports("HasAirplaneMode", HasAirplaneMode)

exports("CreateCall", function(caller, callee, options)
    assert(type(caller) == "table", "caller must be a table")
    assert(type(caller.source) == "number", "caller.source must be a number")
    assert(type(caller.phoneNumber) == "string", "caller.phoneNumber must be a string")
    assert(type(callee) == "string", "callee/options.company must be a string")
    
    if not options then
        options = {}
    end
    assert(type(options) == "table", "options must be a table or nil")
    
    local callerSource = caller.source
    local callerNumber = caller.phoneNumber
    
    if not GetPlayerName(callerSource) then
        return debugprint("CreateCall: callerSrc is not a valid player")
    end
    
    if options.requirePhone then
        if IsPhoneDead(callerNumber) or not HasPhoneItem(callerSource, callerNumber) then
            return debugprint("CreateCall: caller does not have a phone")
        end
    end
    
    if isPlayerInCall(callerSource) then
        return debugprint("CreateCall: caller is already in a call")
    end
    
    local callId = generateCallId()
    local callData = {
        started = os.time(),
        answered = false,
        videoCall = false,
        hideCallerId = options.hideNumber == true,
        callId = callId,
        caller = {
            source = callerSource,
            number = callerNumber
        },
        exportCall = true
    }
    
    if options.company then
        if not Config.Companies.Enabled then
            return debugprint("company calls are disabled in config")
        end
        
        local companyExists = false
        local companyName = callee
        
        if Config.Companies.Contacts[options.company] then
            companyName = Config.Companies.Contacts[options.company].name
            companyExists = true
        else
            for i = 1, #Config.Companies.Services do
                if Config.Companies.Services[i].job == options.company then
                    companyExists = true
                    companyName = Config.Companies.Services[i].name
                    break
                end
            end
        end
        
        if not companyExists then
            return debugprint("invalid company")
        end
        
        callData.company = options.company
        callData.callee = {}
        
        local employees = GetEmployees(options.company)
        for i = 1, #employees do
            local employeeId = employees[i]
            if not isPlayerInCall(employeeId) and employeeId ~= callerSource and not disabledCompanyCalls[employeeId] then
                TriggerClientEvent("phone:phone:setCall", employeeId, {
                    callId = callId,
                    number = callerNumber,
                    company = options.company,
                    companylabel = companyName
                })
            end
        end
    else
        local calleeSource = GetSourceFromNumber(callee)
        if not calleeSource then
            return debugprint("CreateCall: calleeSrc is not a valid player")
        end
        
        if isPlayerInCall(calleeSource) then
            return debugprint("CreateCall: caller or callee is in call")
        end
        
        callData.callee = {
            source = calleeSource,
            number = callee
        }
        
        TriggerClientEvent("phone:phone:setCall", calleeSource, {
            callId = callId,
            number = callerNumber,
            hideCallerId = options.hideNumber == true
        })
    end
    
    activeCalls[callId] = callData
    TriggerEvent("lb-phone:newCall", callData)
    TriggerClientEvent("phone:phone:enableExportCall", callerSource)
    
    return callId
end)

exports("GetCall", function(callId)
    return activeCalls[callId]
end)

exports("AddContact", function(phoneNumber, contactData)
    assert(type(phoneNumber) == "string", "phoneNumber must be a string")
    assert(type(contactData) == "table", "data must be a table")
    
    local success = CreateContact(phoneNumber, contactData)
    debugprint("AddContact: success", success)
    
    local playerId = GetSourceFromNumber(phoneNumber)
    if playerId and success then
        TriggerClientEvent("phone:phone:contactAdded", playerId, contactData)
    end
end)

exports("EndCall", endCall)
exports("IsInCall", isPlayerInCall)

RegisterNetEvent("phone:phone:toggleMute", function(isMuted)
    local playerId = source
    Player(playerId).state.mutedCall = isMuted == true
    
    local inCall, callId = isPlayerInCall(playerId)
    if inCall then
        local callData = activeCalls[callId]
        local otherSource = callData.caller.source == playerId and callData.callee.source or callData.caller.source
        
        if otherSource then
            Player(otherSource).state.otherMutedCall = isMuted == true
        end
    end
end)

RegisterNetEvent("phone:phone:toggleSpeaker", function(isSpeaker)
    Player(source).state.speakerphone = isSpeaker == true
end)

RegisterNetEvent("phone:phone:enteredCallProximity", function(nearbyPlayerId)
    local playerId = source
    local inCall, callId = isPlayerInCall(nearbyPlayerId)
    
    if not inCall then
        return
    end
    
    local callData = activeCalls[callId]
    if not callData.answered then
        return
    end
    
    local isCallerNearby = callData.caller.source == nearbyPlayerId
    local nearbyList = isCallerNearby and callData.caller.nearby or callData.callee.nearby
    local otherSource = isCallerNearby and callData.callee.source or callData.caller.source
    
    if not otherSource then
        return
    end
    
    TriggerClientEvent("phone:phone:addVoiceTarget", otherSource, playerId, true, true)
    TriggerClientEvent("phone:phone:addVoiceTarget", playerId, otherSource, false, true)
    
    if not table.contains(nearbyList, playerId) then
        nearbyList[#nearbyList + 1] = playerId
    end
end)

RegisterNetEvent("phone:phone:leftCallProximity", function(nearbyPlayerId)
    local playerId = source
    local inCall, callId = isPlayerInCall(nearbyPlayerId)
    
    if not inCall then
        return
    end
    
    local callData = activeCalls[callId]
    if not callData.answered then
        return
    end
    
    local isCallerNearby = callData.caller.source == nearbyPlayerId
    local nearbyList = isCallerNearby and callData.caller.nearby or callData.callee.nearby
    
    local contains, index = table.contains(nearbyList, playerId)
    if contains then
        local otherSource = isCallerNearby and callData.callee.source or callData.caller.source
        
        if not otherSource then
            return
        end
        
        TriggerClientEvent("phone:phone:removeVoiceTarget", otherSource, playerId, true)
        TriggerClientEvent("phone:phone:removeVoiceTarget", playerId, otherSource, true)
        
        table.remove(nearbyList, index)
    end
end)

RegisterNetEvent("phone:phone:listenToPlayer", function(targetPlayerId)
    local playerId = source
    debugprint(playerId, "started listening to", targetPlayerId)
    
    TriggerClientEvent("phone:phone:addVoiceTarget", playerId, targetPlayerId, true, true)
    TriggerClientEvent("phone:phone:addVoiceTarget", targetPlayerId, playerId, false, true)
end)

RegisterNetEvent("phone:phone:stopListeningToPlayer", function(targetPlayerId)
    local playerId = source
    debugprint(playerId, "stopped listening to to", targetPlayerId)
    
    TriggerClientEvent("phone:phone:removeVoiceTarget", playerId, targetPlayerId)
    TriggerClientEvent("phone:phone:removeVoiceTarget", targetPlayerId, playerId)
end)

AddEventHandler("playerDropped", function()
    local playerId = source
    disabledCompanyCalls[playerId] = nil
    endCall(playerId)
end)