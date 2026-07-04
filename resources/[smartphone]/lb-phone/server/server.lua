local phoneOwners = {}
local phoneSettings = {}
local settingsChanged = {}

function GenerateString(length)
    local result = ""
    length = length or 15
    
    for i = 1, length do
        local choice = math.random(1, 2)
        if choice == 1 then
            local char = string.char(math.random(97, 122))
            if math.random(1, 2) == 1 then
                char = char:upper()
            end
            result = result .. char
        else
            result = result .. math.random(1, 9)
        end
    end
    
    return result
end

function GenerateId(tableName, columnName)
    local isUnique = nil
    local generatedId = nil
    
    while not isUnique do
        generatedId = GenerateString(5)
        local existingId = MySQL.Sync.fetchScalar(
            "SELECT `" .. columnName .. "` FROM `" .. tableName .. "` WHERE `" .. columnName .. "` = @id",
            { ["@id"] = generatedId }
        )
        isUnique = existingId == nil
        if not isUnique then
            Wait(50)
        end
    end
    
    return generatedId
end

function GeneratePhoneNumber()
    local prefixes = Config.PhoneNumber.Prefixes
    local isUnique = nil
    local phoneNumber = nil
    
    while not isUnique do
        local numberPart = ""
        for i = 1, Config.PhoneNumber.Length do
            numberPart = numberPart .. math.random(0, 9)
        end
        
        if #prefixes == 0 then
            phoneNumber = numberPart
        else
            local randomPrefix = prefixes[math.random(1, #prefixes)]
            phoneNumber = randomPrefix .. numberPart
        end
        
        local existingNumber = MySQL.Sync.fetchScalar(
            "SELECT phone_number FROM phone_phones WHERE phone_number = @number",
            { ["@number"] = phoneNumber }
        )
        isUnique = existingNumber == nil
        if not isUnique then
            Wait(0)
        end
    end
    
    return phoneNumber
end

function GetSettings(phoneNumber)
    return phoneSettings[phoneNumber]
end

exports("GetSettings", GetSettings)

function SetSettings(phoneNumber, settings)
    if not settings then
        if settingsChanged[phoneNumber] then
            settingsChanged[phoneNumber] = nil
            if Config.CacheSettings ~= false then
                debugprint("Updating settings in database for", phoneNumber)
                MySQL.update("UPDATE phone_phones SET settings = ? WHERE phone_number = ?", {
                    json.encode(phoneSettings[phoneNumber]),
                    phoneNumber
                })
            end
        end
    end
    phoneSettings[phoneNumber] = settings
end

function SaveAllSettings()
    if Config.CacheSettings == false then
        return
    end
    
    infoprint("info", "Saving all settings")
    for phoneNumber, settings in pairs(phoneSettings) do
        if settingsChanged[phoneNumber] then
            MySQL.update("UPDATE phone_phones SET settings = ? WHERE phone_number = ?", {
                json.encode(settings),
                phoneNumber
            })
        else
            debugprint("Not saving settings for", phoneNumber, "because no changes were made")
        end
    end
end

RegisterLegacyCallback("playerLoaded", function(playerId, callback)
    local identifier = GetIdentifier(playerId)
    debugprint(GetPlayerName(playerId), playerId, identifier, "triggered phone:playerLoaded")
    
    if not Config.Item.Unique then
        local phoneNumber = MySQL.scalar.await("SELECT phone_number FROM phone_phones WHERE id = ?", { identifier })
        if phoneNumber then
            if HasPhoneItem(playerId, phoneNumber) then
                phoneOwners[phoneNumber] = playerId
                MySQL.update("UPDATE phone_phones SET last_seen = CURRENT_TIMESTAMP WHERE phone_number = ?", { phoneNumber })
            end
        end
        return callback(phoneNumber)
    end
    
    local lastPhoneNumber = MySQL.scalar.await("SELECT phone_number FROM phone_last_phone WHERE id = ?", { identifier })
    debugprint("result from phone_last_phone: ", lastPhoneNumber)
    
    if lastPhoneNumber then
        debugprint("checking if " .. playerId .. " has phone with metadata for last phone number equipped")
        if HasPhoneItem(playerId, lastPhoneNumber) then
            debugprint(playerId .. "has phone with metadata")
            phoneOwners[lastPhoneNumber] = playerId
            MySQL.update("UPDATE phone_phones SET last_seen = CURRENT_TIMESTAMP WHERE phone_number = ?", { lastPhoneNumber })
            return callback(lastPhoneNumber)
        end
        debugprint(playerId .. " doesn't have phone with metadata for last phone number equipped")
        return callback()
    end
    
    debugprint("checking if " .. playerId .. " has an empty phone")
    if not HasPhoneItem(playerId) then
        debugprint(playerId .. " does not have an empty phone")
        return callback()
    end
    
    debugprint(playerId .. " does have an empty phone, checking if they have an existing phone from pre-unique phone")
    local existingPhoneNumber = MySQL.scalar.await("SELECT phone_number FROM phone_phones WHERE id = ? AND assigned = FALSE", { identifier })
    
    if existingPhoneNumber then
        if not SetPhoneNumber(playerId, existingPhoneNumber) then
            debugprint(playerId .. " does not have an existing phone from pre-unique phone, or failed to set number to item metadata")
            return callback()
        end
    else
        debugprint(playerId .. " does not have an existing phone from pre-unique phone, or failed to set number to item metadata")
        return callback()
    end
    
    debugprint(playerId .. " does have an existing phone from pre-unique phone")
    MySQL.update("UPDATE phone_phones SET assigned = TRUE, last_seen = CURRENT_TIMESTAMP WHERE phone_number = ?", { existingPhoneNumber })
    MySQL.update("INSERT INTO phone_last_phone (id, phone_number) VALUES (?, ?)", { identifier, existingPhoneNumber })
    phoneOwners[existingPhoneNumber] = playerId
    callback(existingPhoneNumber)
end)

RegisterLegacyCallback("setLastPhone", function(playerId, callback, phoneNumber)
    local identifier = GetIdentifier(playerId)
    local currentPhoneNumber = GetEquippedPhoneNumber(playerId)
    SaveBattery(playerId)
    
    if not phoneNumber then
        MySQL.update("DELETE FROM phone_last_phone WHERE id = ?", { identifier })
        if currentPhoneNumber then
            phoneOwners[currentPhoneNumber] = nil
            local playerState = Player(playerId).state
            playerState.phoneOpen = false
            playerState.phoneName = nil
            playerState.phoneNumber = nil
            
            local settings = GetSettings(currentPhoneNumber)
            if settings then
                SetSettings(currentPhoneNumber, nil)
            end
        end
        return callback()
    end
    
    if phoneOwners[phoneNumber] then
        if phoneOwners[phoneNumber] ~= playerId then
            return callback()
        end
    end
    
    local phoneExists = MySQL.scalar.await("SELECT 1 FROM phone_phones WHERE phone_number = ?", { phoneNumber })
    if not phoneExists then
        infoprint("warning", GetPlayerName(playerId) .. " | " .. playerId .. " tried to use a phone with a number that doesn't exist. This usually happens when you delete the phone from phone_phones, without deleting the phone item from the player's inventory. Phone number: " .. phoneNumber)
        return callback()
    end
    
    MySQL.update.await("INSERT INTO phone_last_phone (id, phone_number) VALUES (?, ?) ON DUPLICATE KEY UPDATE phone_number = ?", {
        identifier, phoneNumber, phoneNumber
    })
    
    if currentPhoneNumber then
        phoneOwners[currentPhoneNumber] = nil
        local settings = GetSettings(currentPhoneNumber)
        if settings then
            SetSettings(currentPhoneNumber, nil)
        end
    end
    
    phoneOwners[phoneNumber] = playerId
    callback()
end)

RegisterLegacyCallback("generatePhoneNumber", function(playerId, callback)
    local identifier = GetIdentifier(playerId)
    local phoneId = identifier
    debugprint(GetPlayerName(playerId), playerId, identifier, "wants to generate a phone number")
    
    if Config.Item.Unique then
        debugprint("unique phones enabled, checking if " .. GetPlayerName(playerId) .. " has a phone item without a number assigned")
        if not HasPhoneItem(playerId) then
            debugprint(GetPlayerName(playerId) .. " does not have a phone item without a number assigned")
            return callback()
        end
        phoneId = GenerateId("phone_phones", "id")
    else
        local existingPhoneNumber = MySQL.scalar.await("SELECT phone_number FROM phone_phones WHERE id = ?", { identifier })
        if existingPhoneNumber then
            infoprint("warning", GetPlayerName(playerId) .. " wants to generate a phone number, but they already have one. Please set Config.Debug to true, and send the full log in customer-support if this happens again.")
            phoneOwners[existingPhoneNumber] = playerId
            return callback(existingPhoneNumber)
        end
    end
    
    local phoneNumber = GeneratePhoneNumber()
    MySQL.update.await("INSERT INTO phone_phones (id, owner_id, phone_number) VALUES (?, ?, ?)", {
        phoneId, identifier, phoneNumber
    })
    
    TriggerEvent("lb-phone:phoneNumberGenerated", playerId, phoneNumber)
    
    if Config.Item.Unique then
        SetPhoneNumber(playerId, phoneNumber)
        MySQL.update.await("UPDATE phone_phones SET assigned = TRUE WHERE phone_number = ?", { phoneNumber })
        MySQL.update.await("INSERT INTO phone_last_phone (id, phone_number) VALUES (?, ?) ON DUPLICATE KEY UPDATE phone_number = ?", {
            GetIdentifier(playerId), phoneNumber, phoneNumber
        })
    end
    
    phoneOwners[phoneNumber] = playerId
    callback(phoneNumber)
end)

RegisterLegacyCallback("getPhone", function(playerId, callback, phoneNumber)
    debugprint(GetPlayerName(playerId), "triggered phone:getPhone. checking if they have an item")
    
    if not HasPhoneItem(playerId, phoneNumber) then
        debugprint(GetPlayerName(playerId), "does not have an item")
        return callback()
    end
    
    debugprint(GetPlayerName(playerId), "has an item, getting phone data")
    local phoneData = MySQL.single.await("SELECT owner_id, is_setup, settings, `name`, battery FROM phone_phones WHERE phone_number = ?", { phoneNumber })
    
    if not phoneData then
        debugprint(GetPlayerName(playerId), "does not have any phone data")
        return callback()
    end
    
    if phoneData.settings then
        local cachedSettings = GetSettings(phoneNumber)
        if not cachedSettings then
            phoneData.settings = json.decode(phoneData.settings)
            SetSettings(phoneNumber, phoneData.settings)
        else
            phoneData.settings = cachedSettings
        end
    end
    
    debugprint(GetPlayerName(playerId), "has phone data")
    
    if not phoneData.owner_id then
        debugprint(GetPlayerName(playerId) .. "'s phone does not have an owner, setting owner to " .. GetIdentifier(playerId))
        MySQL.update("UPDATE phone_phones SET owner_id = ? WHERE phone_number = ?", {
            GetIdentifier(playerId), phoneNumber
        })
    end
    
    return callback(phoneData)
end)

function GetEquippedPhoneNumber(playerId, callback)
    for phoneNumber, owner in pairs(phoneOwners) do
        if owner == playerId then
            if callback then
                callback(phoneNumber)
            end
            return phoneNumber
        end
    end
end

function GetSourceFromNumber(phoneNumber)
    if not phoneNumber then
        return false
    end
    return phoneOwners[phoneNumber] or false
end

exports("GetSourceFromNumber", GetSourceFromNumber)

RegisterLegacyCallback("isAdmin", function(playerId, callback)
    callback(IsAdmin(playerId))
end)

RegisterLegacyCallback("getCharacterName", function(playerId, callback)
    local firstname, lastname = GetCharacterName(playerId)
    callback({
        firstname = firstname,
        lastname = lastname
    })
end)

local latestVersion = nil
PerformHttpRequest("https://loaf-scripts.com/versions/phone/version.json", function(statusCode, responseBody, headers, errorData)
    if statusCode ~= 200 then
        debugprint("Failed to get latest script version")
        debugprint("Status:", statusCode)
        debugprint("Body:", responseBody)
        debugprint("Headers:", headers)
        debugprint("Error:", errorData)
        return
    end
    
    local versionData = json.decode(responseBody)
    latestVersion = versionData.latest
end, "GET")

RegisterCallback("getLatestVersion", function()
    return latestVersion
end)

RegisterNetEvent("phone:finishedSetup", function(settings)
    local playerId = source
    local phoneNumber = GetEquippedPhoneNumber(playerId)
    if not phoneNumber then
        return
    end
    
    SetSettings(phoneNumber, settings)
    MySQL.update("UPDATE phone_phones SET is_setup = true, settings = ? WHERE phone_number = ?", {
        json.encode(settings), phoneNumber
    })
    
    if Config.AutoCreateEmail then
        GenerateEmailAccount(playerId, phoneNumber)
    end
end)

RegisterNetEvent("phone:setName", function(phoneName)
    local playerId = source
    local phoneNumber = GetEquippedPhoneNumber(playerId)
    if not phoneNumber then
        return
    end
    
    if Config.NameFilter then
        if not phoneName:match(Config.NameFilter) then
            infoprint("warning", "Player " .. GetPlayerName(playerId) .. " tried to set an invalid phone name: " .. phoneName)
            local firstname, lastname = GetCharacterName(playerId)
            phoneName = L("BACKEND.MISC.X_PHONE", {
                name = firstname,
                lastname = lastname
            })
        end
    end
    
    MySQL.Async.execute("UPDATE phone_phones SET `name`=@name WHERE phone_number=@phoneNumber", {
        ["@phoneNumber"] = phoneNumber,
        ["@name"] = phoneName
    })
    
    if Config.Item.Unique then
        if SetItemName then
            SetItemName(playerId, phoneNumber, phoneName)
        end
    end
    
    local settings = GetSettings(phoneNumber)
    if settings then
        settings.name = phoneName
    end
    
    Player(playerId).state.phoneName = phoneName
end)

BaseCallback("setSettings", function(playerId, phoneNumber, settings)
    debugprint(playerId, "saving settings for phone number", phoneNumber)
    settingsChanged[phoneNumber] = true
    SetSettings(phoneNumber, settings)
    
    if Config.CacheSettings == false then
        MySQL.update("UPDATE phone_phones SET settings = ? WHERE phone_number = ?", {
            json.encode(settings), phoneNumber
        })
    end
end)

RegisterNetEvent("phone:togglePhone", function(isOpen, phoneName)
    local playerId = source
    local playerState = Player(playerId).state
    playerState.phoneOpen = isOpen
    
    local phoneNumber = GetEquippedPhoneNumber(playerId)
    if not phoneNumber then
        return
    end
    
    playerState.phoneName = phoneName
    playerState.phoneNumber = phoneNumber
end)

RegisterNetEvent("phone:toggleFlashlight", function(isOn)
    Player(source).state.flashlight = isOn
end)

local phoneObjects = {}

RegisterNetEvent("phone:setPhoneObject", function(objectNetId)
    local playerId = source
    
    if Config.ServerSideSpawn and not objectNetId then
        local existingObject = phoneObjects[playerId]
        if existingObject then
            debugprint("Deleting phone object for player " .. playerId)
            DeleteEntity(NetworkGetEntityFromNetworkId(existingObject))
        end
    end
    
    phoneObjects[playerId] = objectNetId
end)

AddEventHandler("playerDropped", function()
    local playerId = source
    local phoneObject = phoneObjects[playerId]
    local phoneNumber = GetEquippedPhoneNumber(playerId)
    
    if phoneObject then
        local entity = NetworkGetEntityFromNetworkId(phoneObject)
        if entity then
            DeleteEntity(entity)
        end
        phoneObjects[playerId] = nil
    end
    
    if phoneNumber then
        Wait(1000)
        SetSettings(phoneNumber, nil)
        phoneOwners[phoneNumber] = nil
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    
    for playerId, phoneObject in pairs(phoneObjects) do
        local entity = NetworkGetEntityFromNetworkId(phoneObject)
        if entity then
            DeleteEntity(entity)
        end
    end
    
    SaveAllSettings()
end)

AddEventHandler("txAdmin:events:serverShuttingDown", function()
    SaveAllSettings()
end)

local function FactoryReset(phoneNumber)
    MySQL.update.await("DELETE FROM phone_logged_in_accounts WHERE phone_number = ?", { phoneNumber })
    local affectedRows = MySQL.update.await("UPDATE phone_phones SET is_setup = false, settings = NULL, pin = NULL, face_id = NULL WHERE phone_number = ?", { phoneNumber })
    
    if affectedRows > 0 then
        local playerId = phoneOwners[phoneNumber]
        if playerId then
            TriggerClientEvent("phone:factoryReset", playerId)
            SetSettings(phoneNumber, nil)
            phoneOwners[phoneNumber] = nil
        end
    end
end

RegisterNetEvent("phone:factoryReset", function()
    local phoneNumber = GetEquippedPhoneNumber(source)
    if not phoneNumber then
        return
    end
    FactoryReset(phoneNumber)
end)

exports("FactoryReset", FactoryReset)