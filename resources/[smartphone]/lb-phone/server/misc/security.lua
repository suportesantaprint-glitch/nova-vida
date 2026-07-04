RegisterLegacyCallback("security:getIdentifier", function(source, callback)
    callback(GetIdentifier(source))
end)

BaseCallback("security:setPin", function(source, phoneNumber, newPin, currentPin)
    if type(newPin) ~= "string" or #newPin ~= 4 then
        debugprint("Failed to set pin: invalid type or length")
        return false
    end
    
    local affectedRows = MySQL.update.await(
        "UPDATE phone_phones SET pin = ? WHERE phone_number = ? AND (pin = ? OR pin IS NULL)",
        {newPin, phoneNumber, currentPin or ""}
    )
    
    local success = affectedRows > 0
    debugprint("phone:security:setPin", GetPlayerName(source), success, phoneNumber, newPin, currentPin)
    
    return success
end, false)

BaseCallback("security:removePin", function(source, phoneNumber, currentPin)
    if type(currentPin) ~= "string" or #currentPin ~= 4 then
        debugprint("Failed to remove pin: invalid type or length")
        return false
    end
    
    local affectedRows = MySQL.update.await(
        "UPDATE phone_phones SET pin = NULL, face_id = NULL WHERE phone_number = ? AND (pin = ? OR pin IS NULL)",
        {phoneNumber, currentPin}
    )
    
    return affectedRows > 0
end, false)

BaseCallback("security:verifyPin", function(source, phoneNumber, enteredPin)
    if type(enteredPin) ~= "string" or #enteredPin ~= 4 then
        debugprint("Failed to verify pin: invalid type or length")
        return false
    end
    
    local storedPin = MySQL.scalar.await(
        "SELECT pin FROM phone_phones WHERE phone_number = ?",
        {phoneNumber}
    )
    
    local isValid = storedPin == nil or storedPin == enteredPin
    debugprint("phone:security:verifyPin", GetPlayerName(source), isValid, storedPin, enteredPin)
    
    return isValid
end, false)

BaseCallback("security:enableFaceUnlock", function(source, phoneNumber, pin)
    if type(pin) ~= "string" or #pin ~= 4 then
        debugprint("Failed to enable face unlock: invalid type or length")
        return false
    end
    
    local playerIdentifier = GetIdentifier(source)
    local affectedRows = MySQL.update.await(
        "UPDATE phone_phones SET face_id = ? WHERE phone_number = ? AND pin = ?",
        {playerIdentifier, phoneNumber, pin}
    )
    
    return affectedRows > 0
end, false)

BaseCallback("security:disableFaceUnlock", function(source, phoneNumber, pin)
    if type(pin) ~= "string" or #pin ~= 4 then
        debugprint("Failed to disable face unlock: invalid type or length")
        return false
    end
    
    return MySQL.update.await(
        "UPDATE phone_phones SET face_id = NULL WHERE phone_number = ? AND (pin = ? OR pin IS NULL)",
        {phoneNumber, pin}
    )
end, false)

BaseCallback("security:verifyFace", function(source, phoneNumber)
    local playerIdentifier = GetIdentifier(source)
    local storedFaceId = MySQL.scalar.await(
        "SELECT face_id FROM phone_phones WHERE phone_number = ?",
        {phoneNumber}
    )
    
    debugprint("phone:security:verifyFace", GetPlayerName(source), storedFaceId, playerIdentifier)
    
    return storedFaceId == playerIdentifier
end, false)

function ResetSecurity(phoneNumber)
    assert(type(phoneNumber) == "string", "Invalid argument #1 to ResetSecurity, expected string, got " .. type(phoneNumber))
    
    MySQL.update.await(
        "UPDATE phone_phones SET pin = NULL, face_id = NULL WHERE phone_number = ?",
        {phoneNumber}
    )
    
    local source = GetSourceFromNumber(phoneNumber)
    if source then
        TriggerClientEvent("phone:security:reset", source, phoneNumber)
    end
end

exports("GetPin", function(phoneNumber)
    assert(type(phoneNumber) == "string", "Invalid argument #1 to GetPin, expected string, got " .. type(phoneNumber))
    
    return MySQL.scalar.await(
        "SELECT pin FROM phone_phones WHERE phone_number = ?",
        {phoneNumber}
    )
end)

exports("ResetSecurity", ResetSecurity)