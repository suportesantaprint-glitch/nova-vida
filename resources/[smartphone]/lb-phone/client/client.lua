local DisableControlAction = DisableControlAction
local IsNuiFocused = IsNuiFocused
local DisablePlayerFiring = DisablePlayerFiring

phoneData = nil
currentPhone = nil
settings = nil
phoneOpen = false
SavedLocations = {}
PhoneOnScreen = false

local playerData = nil
local hasLoadedPlayer = nil
local fetchingPhone = nil
local configSentToUI = nil
local waitingForPTT = false

local function waitForConfig()
    if configSentToUI then
        return
    end
    
    debugprint("waiting for config to be received")
    while not configSentToUI do
        Wait(0)
    end
    debugprint("config received")
end

function FetchPhone()
    debugprint("FetchPhone triggered")
    
    if fetchingPhone then
        debugprint("already fetching phone")
        return
    elseif not configSentToUI then
        debugprint("config has not been sent to UI yet")
        return
    end
    
    fetchingPhone = true
    
    while not FrameworkLoaded do
        debugprint("waiting for framework to load")
        Wait(500)
    end
    
    debugprint("triggering phone:playerLoaded")
    
    local phoneNumber = nil
    if not hasLoadedPlayer or not currentPhone then
        phoneNumber = AwaitCallback("playerLoaded")
        playerData = phoneNumber
        hasLoadedPlayer = true
    else
        phoneNumber = playerData
    end
    
    debugprint("got number", phoneNumber)
    
    if not phoneNumber then
        debugprint("no number, checking if player has item")
        if HasPhoneItem() then
            debugprint("player has item; triggering phone:generatePhoneNumber")
            phoneNumber = AwaitCallback("generatePhoneNumber")
            debugprint("got number", phoneNumber)
        else
            debugprint("player does not have item")
        end
    end
    
    if not phoneNumber then
        fetchingPhone = false
        if currentPhone then
            debugprint("no number. using SetPhone")
            SetPhone()
        end
        debugprint("no number, returning")
        return
    end
    
    local defaultSettings = json.decode(GetConfigFile("defaultSettings.json"))
    local latestVersion = AwaitCallback("getLatestVersion")
    local currentVersion = GetResourceMetadata(GetCurrentResourceName(), "version", 0)
    
    if not latestVersion then
        latestVersion = currentVersion
    end
    
    defaultSettings.locale = Config.DefaultLocale
    defaultSettings.version = currentVersion
    defaultSettings.latestVersion = latestVersion
    
    local isSetup = false
    
    debugprint("fetching phone data")
    local phoneDataResult = AwaitCallback("getPhone", phoneNumber)
    debugprint("got phone data", json.encode(phoneDataResult))
    
    if phoneDataResult then
        if phoneDataResult.settings then
            defaultSettings = phoneDataResult.settings
        end
        
        if phoneDataResult.name then
            defaultSettings.name = phoneDataResult.name
        else
            defaultSettings.name = "Not set"
        end
        
        defaultSettings.version = currentVersion
        defaultSettings.latestVersion = latestVersion
        
        SavedLocations = AwaitCallback("maps:getSavedLocations")
        
        isSetup = phoneDataResult.is_setup or isSetup
        if not phoneDataResult.is_setup then
            isSetup = false
        end
        
        currentPhone = phoneNumber
        
        phoneData = {
            isSetup = isSetup,
            phoneNumber = phoneNumber,
            settings = defaultSettings,
            battery = (Config.Battery.Enabled and phoneDataResult.battery) or 100
        }
        
        waitForConfig()
        debugprint("triggering phone:setPhoneData")
        SendReactMessage("setPhoneData", phoneData)
        TriggerEvent("lb-phone:numberChanged", phoneNumber)
        Wait(250)
    end
    
    settings = defaultSettings
    fetchingPhone = false
end

function RefreshPhone(skipFetch)
    debugprint("RefreshPhone triggered")
    
    if fetchingPhone then
        debugprint("phone is being fetched, waiting before refreshing")
        while fetchingPhone do
            Wait(0)
        end
    end
    
    if Config.DynamicWebRTC and Config.DynamicWebRTC.Enabled then
        local webRTCCredentials = AwaitCallback("getWebRTCCredentials")
        
        if Config.DynamicWebRTC.RemoveStun and webRTCCredentials then
            for i = #webRTCCredentials, 1, -1 do
                if not webRTCCredentials[i].credential then
                    table.remove(webRTCCredentials, i)
                end
            end
        end
        
        if webRTCCredentials then
            Config.RTCConfig = Config.RTCConfig or {}
            Config.RTCConfig.iceServers = webRTCCredentials
        end
    end
    
    configSentToUI = false
    
    local configData = json.decode(GetConfigFile("config.json"))
    
    local valetConfig = {
        enabled = Config.Valet.Enabled or false,
        price = Config.Valet.Price or 0,
        vehicleTypes = Config.Valet.VehicleTypes or {"car"}
    }
    
    configData.valet = valetConfig
    configData.locations = Config.Locations
    configData.AllowExternal = Config.AllowExternal
    configData.ExternalBlacklistedDomains = Config.ExternalBlacklistedDomains
    configData.ExternalWhitelistedDomains = Config.ExternalWhitelistedDomains
    configData.Format = Config.PhoneNumber.Format
    configData.EmailDomain = Config.EmailDomain
    configData.RealTime = Config.RealTime
    configData.CurrencyFormat = Config.CurrencyFormat
    configData.DeleteMessages = Config.DeleteMessages
    configData.Battery = Config.Battery
    configData.rtc = Config.RTCConfig
    configData.PromoteBirdy = Config.PromoteBirdy
    configData.DynamicIsland = Config.DynamicIsland
    configData.SetupScreen = Config.SetupScreen
    configData.MaxTransferAmount = Config.MaxTransferAmount
    configData.EnableMessagePay = Config.EnableMessagePay
    configData.EnableGIFs = Config.EnableGIFs
    configData.GIFsFilter = Config.GIFsFilter or "low"
    configData.EnableVoiceMessages = Config.EnableVoiceMessages
    configData.DefaultLocale = Config.DefaultLocale
    configData.DateLocale = Config.DateLocale
    configData.Debug = Config.Debug
    configData.TikTokTTS = Config.TrendyTTS or {{"English (US) - Female", "en_us_001"}}
    configData.recordNearbyVoices = Config.Voice.RecordNearby
    configData.frameColor = Config.FrameColor
    configData.allowFrameColorChange = Config.AllowFrameColorChange
    configData.unlockPhoneKey = Config.KeyBinds.UnlockPhone and Config.KeyBinds.UnlockPhone.Bind or nil
    configData.DeleteMail = Config.DeleteMail
    configData.ChangePassword = Config.ChangePassword
    configData.DeleteAccount = Config.DeleteAccount
    configData.CustomCamera = (Config.Camera and Config.Camera.Enabled) or false
    configData.UsernameFilter = (Config.UsernameFilter and Config.UsernameFilter.Regex) or "[a-zA-Z0-9]+"
    configData.CryptoLimit = (Config.Crypto and Config.Crypto.Limits) or {Buy = 10000, Sell = 10000}
    
    local imageOptions = {
        mime = (Config.Image and Config.Image.Mime) or "image/png",
        quality = (Config.Image and Config.Image.Quality) or 1.0
    }
    configData.imageOptions = imageOptions
    
    local videoOptions = {
        bitrate = (Config.Video and Config.Video.Bitrate) or 250,
        size = (Config.Video and Config.Video.MaxSize) or 10,
        duration = (Config.Video and Config.Video.MaxDuration) or 60,
        fps = (Config.Video and Config.Video.FrameRate) or 24
    }
    configData.videoOptions = videoOptions
    
    configData.Companies = table.deep_clone(Config.Companies)
    
    if configData.Companies and configData.Companies.Services then
        for i = 1, #configData.Companies.Services do
            local service = configData.Companies.Services[i]
            if service.onCustomIconClick then
                service.onCustomIconClick = true
            end
        end
    end
    
    if Config.CustomApps then
        for appName, appData in pairs(Config.CustomApps) do
            configData.apps[appName] = FormatCustomAppDataForUI(appData)
        end
    end
    
    for appName, appData in pairs(configData.apps) do
        appData.access = HasAccessToApp(appName)
    end
    
    local defaultSettings = json.decode(GetConfigFile("defaultSettings.json"))
    configData.defaultSettings = defaultSettings
    
    local function removeAppFromDefaults(appName)
        local appsList = configData.defaultSettings.apps
        for i = 1, #appsList do
            for j = 1, #appsList[i] do
                if appsList[i][j] == appName then
                    debugprint("app removed", j, appName)
                    table.remove(appsList[i], j)
                    break
                end
            end
        end
    end
    
    if Config.Framework == "standalone" and not Config.CustomFramework then
        configData.apps.Wallet = nil
        configData.apps.Home = nil
        configData.apps.Garage = nil
        configData.apps.Services = nil
        removeAppFromDefaults("Wallet")
        removeAppFromDefaults("Home")
        removeAppFromDefaults("Garage")
        removeAppFromDefaults("Services")
    end
    
    if not Config.HouseScript then
        configData.apps.Home = nil
        debugprint("No Config.HouseScript, removed home app")
        removeAppFromDefaults("Home")
    end
    
    if not (Config.Crypto and Config.Crypto.Enabled) then
        configData.apps.Crypto = nil
        debugprint("Config.Crypto not enabled, removed crypto app")
        removeAppFromDefaults("Crypto")
    end
    
    SendReactMessage("setConfig", configData)
    waitForConfig()
    
    if phoneData then
        debugprint("phoneData is defined")
        SendReactMessage("setPhoneData", phoneData)
        return
    end
    
    if skipFetch then
        return
    end
    
    FetchPhone()
end

RegisterNetEvent("lb-phone:jobUpdated", function(jobData)
    if not Config.WhitelistApps and not Config.BlacklistApps then
        return
    end
    
    debugprint("Job updated, refreshing whitelisted & blacklisted apps")
    
    for appName, _ in pairs(Config.WhitelistApps) do
        SendReactMessage("app:setHasAccess", {
            app = appName,
            hasAccess = HasAccessToApp(appName, jobData.job, jobData.grade)
        })
    end
    
    for appName, _ in pairs(Config.BlacklistApps) do
        SendReactMessage("app:setHasAccess", {
            app = appName,
            hasAccess = HasAccessToApp(appName, jobData.job, jobData.grade)
        })
    end
    
    for appName, _ in pairs(Config.CustomApps) do
        SendReactMessage("app:setHasAccess", {
            app = appName,
            hasAccess = HasAccessToApp(appName, jobData.job, jobData.grade)
        })
    end
end)

RegisterNUICallback("configReceived", function(data, cb)
    debugprint("UI has received the config (configReceived triggered)")
    configSentToUI = true
    cb("ok")
end)

RegisterNUICallback("getPhoneData", function(data, cb)
    debugprint("getPhoneData triggered")
    
    while not FrameworkLoaded do
        Wait(500)
    end
    
    Wait(1000)
    RefreshPhone()
    
    if not cb then
        return debugprint("cb is not defined in getPhoneData", data)
    end
    
    cb(true)
end)

local function disableControls()
    local playerId = PlayerId()
    
    while phoneOpen do
        Wait(0)
        
        DisableControlAction(0, 199, true)
        DisableControlAction(0, 200, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 69, true)
        DisableControlAction(0, 70, true)
        DisableControlAction(0, 91, true)
        DisableControlAction(0, 92, true)
        DisableControlAction(0, 106, true)
        DisableControlAction(0, 114, true)
        DisableControlAction(0, 140, true)
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, 257, true)
        DisableControlAction(0, 263, true)
        DisableControlAction(0, 264, true)
        DisableControlAction(0, 330, true)
        DisableControlAction(0, 331, true)
        DisablePlayerFiring(playerId, true)
        
        if IsNuiFocused() then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 245, true)
            DisableControlAction(0, 14, true)
            DisableControlAction(0, 15, true)
            DisableControlAction(0, 16, true)
            DisableControlAction(0, 17, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 50, true)
            DisableControlAction(0, 99, true)
            DisableControlAction(0, 115, true)
            DisableControlAction(0, 180, true)
            DisableControlAction(0, 181, true)
            DisableControlAction(0, 198, true)
            DisableControlAction(0, 241, true)
            DisableControlAction(0, 242, true)
            DisableControlAction(0, 261, true)
            DisableControlAction(0, 262, true)
            DisableControlAction(0, 85, true)
        end
    end
    
    while IsDisabledControlPressed(0, 200) do
        DisableControlAction(0, 200, true)
        Wait(0)
    end
    
    if cameraOpen then
        if IsWalkingCamEnabled() then
            local wasSelfieCam = IsSelfieCam()
            DisableWalkableCam()
            
            while not phoneOpen do
                Wait(500)
            end
            
            if cameraOpen then
                SetPhoneAction("camera")
                EnableWalkableCam(wasSelfieCam)
            end
        end
    end
end

function ToggleOpen(open, skipFocus)
    if open == nil then
        open = not phoneOpen
    end
    
    open = open == true
    
    debugprint("ToggleOpen triggered", tostring(open), tostring(skipFocus))
    
    if phoneDisabled and open then
        debugprint("phone is disabled, returning")
        return
    elseif phoneOpen == open then
        debugprint("phoneOpen & open are both the same value, returning")
        return
    elseif not FrameworkLoaded then
        infoprint("warning", "Framework not loaded")
        return
    elseif open and IsPedDeadOrDying(PlayerPedId(), true) then
        debugprint("player ped is dead/dying, returning")
        return
    elseif open and CanOpenPhone and not CanOpenPhone() then
        debugprint("CanOpenPhone returned false, returning")
        return
    elseif open and IsNuiFocused() and Config.DisableOpenNUI then
        infoprint("info", "Not opening the phone as another script has NUI focus. You can disable this behavior by setting Config.DisableOpenNUI to false.")
        return
    elseif GetResourceState("lb-tablet") == "started" then
        local success, isTabletOpen = pcall(function()
            return exports["lb-tablet"]:IsOpen()
        end)
        if success and isTabletOpen then
            infoprint("info", "Not opening the phone as the tablet is open. You can disable this behavior by setting Config.DisableTabletOpenPhone to false.")
            return
        end
    end
    
    if not currentPhone then
        debugprint("no phone, fetching")
        FetchPhone()
        if not currentPhone then
            debugprint("still no phone after fetching, returning")
            return
        end
    end
    
    if open and not HasPhoneItem(currentPhone) then
        debugprint("HasPhoneItem returned false. Phone number:", tostring(currentPhone))
        TriggerServerEvent("phone:togglePhone")
        SendReactMessage("closePhone")
        return
    end
    
    if not open then
        if IsWalkingCamEnabled() and IsSelfieCam() then
            ToggleSelfieCam(false)
        end
    end
    
    if not open and Config.EndLiveClose then
        local liveData = IsWatchingLive()
        EndLive()
        if liveData then
            SendReactMessage("instagram:liveEnded", liveData)
        end
    end
    
    phoneOpen = open
    
    if open then
        debugprint("should open phone. sending openPhone event to ui")
        SendReactMessage("openPhone")
        
        if not skipFocus then
            SetNuiFocus(true, true)
            SetNuiFocusKeepInput(Config.KeepInput)
        end
        
        if Config.KeepInput then
            CreateThread(disableControls)
        end
        
        if ControllerThread then
            CreateThread(ControllerThread)
        end
        
        debugprint("setting animation action")
        if IsWalkingCamEnabled() then
            SetPhoneAction("camera")
        elseif IsInCall() then
            SetPhoneAction("call")
        else
            SetPhoneAction("default")
        end
    else
        debugprint("sending closePhone event to ui")
        PlayCloseAnim()
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendReactMessage("closePhone")
    end
    
    if phoneData and phoneData.isSetup then
        TriggerServerEvent("phone:togglePhone", open, settings and settings.name)
    end
    
    TriggerEvent("lb-phone:phoneToggled", open)
end

RegisterNUICallback("toggleInput", function(enable, cb)
    cb("ok")
    
    if not Config.KeepInput then
        return
    end
    
    local isPTTPressed = (Config.DisableFocusTalking and IsDisabledControlPressed(0, 249)) or IsDisabledControlJustReleased(0, 249)
    
    if isPTTPressed then
        if enable then
            debugprint("PTT is pressed, ignoring toggle focus")
            return
        end
        
        debugprint("PTT is pressed, waiting before toggling focus")
        while (Config.DisableFocusTalking and IsDisabledControlPressed(0, 249)) or IsDisabledControlJustReleased(0, 249) do
            Wait(100)
        end
    end
    
    if enable then
        Wait(200)
    end
    
    SetNuiFocusKeepInput(not enable)
end)

AddEventHandler("lb-phone:keyPressed", function(key)
    if IsPauseMenuActive() then
        return
    end
    
    if key == "Open" then
        debugprint("Pressed open keybind")
        ToggleOpen(not phoneOpen)
    elseif key == "Focus" then
        if not phoneOpen or waitingForPTT then
            return
        end
        
        local isPTTPressed = (Config.DisableFocusTalking and IsDisabledControlPressed(0, 249)) or IsDisabledControlJustReleased(0, 249)
        
        if isPTTPressed then
            debugprint("PTT is pressed, waiting before toggling focus")
            waitingForPTT = true
            while IsDisabledControlPressed(0, 249) or IsDisabledControlJustReleased(0, 249) do
                Wait(0)
            end
            waitingForPTT = false
        end
        
        local hasFocus = IsNuiFocused()
        SetNuiFocus(not hasFocus, not hasFocus)
        
        if not hasFocus then
            SetNuiFocusKeepInput(Config.KeepInput)
        else
            SetNuiFocusKeepInput(false)
        end
    elseif key == "StopSounds" then
        SendReactMessage("stopSounds")
    end
    
    if key == "AnswerCall" then
        SendReactMessage("usedCommand", "answer")
    elseif key == "DeclineCall" then
        SendReactMessage("usedCommand", "decline")
    end
    
    if key == "TakePhoto" then
        SendReactMessage("camera:usedCommand", "toggleTaking")
    elseif key == "ToggleFlash" then
        SendReactMessage("camera:usedCommand", "toggleFlash")
    elseif key == "LeftMode" then
        SendReactMessage("camera:usedCommand", "leftMode")
    elseif key == "RightMode" then
        SendReactMessage("camera:usedCommand", "rightMode")
    elseif key == "FlipCamera" then
        SendReactMessage("camera:usedCommand", "toggleFlip")
    end
end)

for keyName, keyData in pairs(Config.KeyBinds) do
    if not keyData.Command then
        goto continue
    end
    
    keyData.Command = keyData.Command:lower()
    
    if keyData.Bind then
        keyData.bindData = AddKeyBind({
            name = keyData.Command,
            description = keyData.Description or "no description",
            defaultKey = keyData.Bind,
            defaultMapper = keyData.Mapper,
            secondaryKey = keyData.SecondaryBind,
            secondaryMapper = keyData.SecondaryMapper,
            onPress = function()
                TriggerEvent("lb-phone:keyPressed", keyName)
            end,
            onRelease = function(duration)
                TriggerEvent("lb-tablet:keyReleased", keyName, duration)
            end
        })
    else
        RegisterCommand(keyData.Command, function()
            TriggerEvent("lb-phone:keyPressed", keyName)
            Wait(0)
            TriggerEvent("lb-phone:keyReleased", keyName, 0)
        end, false)
    end
    
    ::continue::
end

RegisterNUICallback("finishedSetup", function(data, cb)
    if phoneData then
        phoneData.isSetup = true
    end
    
    if data then
        local characterName = AwaitCallback("getCharacterName")
        data.name = L("BACKEND.MISC.X_PHONE", {
            name = characterName.firstname,
            lastname = characterName.lastname
        })
    end
    
    SendReactMessage("setName", data.name)
    TriggerServerEvent("phone:setName", data.name)
    TriggerServerEvent("phone:togglePhone", phoneOpen, data and data.name)
    TriggerServerEvent("phone:finishedSetup", data)
    
    if Config.AutoBackup then
        TriggerCallback("backup:createBackup")
    end
    
    cb("ok")
end)

RegisterNUICallback("isAdmin", function(data, cb)
    TriggerCallback("isAdmin", cb)
end)

RegisterNUICallback("setPhoneName", function(name, cb)
    if settings then
        settings.name = name
    end
    
    TriggerServerEvent("phone:setName", name)
    cb("ok")
end)

RegisterNUICallback("setSettings", function(newSettings, cb)
    debugprint("setSettings triggered")
    
    if not phoneData then
        print("setSettings triggered, but phoneData is nil")
        return
    end
    
    settings = newSettings
    phoneData.settings = settings
    cb("ok")
    
    SetCallVolume(settings and settings.sound and settings.sound.callVolume)
    AwaitCallback("setSettings", settings)
    TriggerEvent("lb-phone:settingsUpdated", newSettings)
    
    SendReactMessage("customApp:sendMessage", {
        identifier = "any",
        message = {
            type = "settingsUpdated",
            settings = settings,
            action = "settingsUpdated",
            data = newSettings
        }
    })
end)

RegisterNUICallback("setCursorLocation", function(data, cb)
    local x, y = data.x, data.y
    local screenWidth, screenHeight = GetActiveScreenResolution()
    SetCursorLocation(x / screenWidth, y / screenHeight)
    cb("ok")
end)

RegisterNUICallback("exitFocus", function(data, cb)
    debugprint("exitFocus triggered")
    SetNuiFocus(false, false)
    ToggleOpen(false)
    cb("ok")
end)

RegisterNUICallback("getLocales", function(data, cb)
    cb(Config.Locales or {en = "English"})
end)

RegisterNUICallback("setOnScreen", function(isOnScreen, cb)
    isOnScreen = isOnScreen == true
    
    if isOnScreen ~= PhoneOnScreen then
        TriggerEvent("lb-phone:setOnScreen", isOnScreen)
        PhoneOnScreen = isOnScreen
    end
    
    cb("ok")
end)

exports("IsPhoneOnScreen", function()
    return PhoneOnScreen
end)

function SendReactMessage(action, data)
    SendNUIMessage({
        action = action,
        data = data
    })
end

CreateThread(function()
    local lastTime = {}
    local lastService = nil
    
    while not currentPhone do
        debugprint("Waiting for currentPhone to be set before updating time & service")
        Wait(1000)
    end
    
    while true do
        local currentTime
        if not Config.RealTime then
            if Config.CustomTime then
                currentTime = Config.CustomTime()
            else
                currentTime = {
                    hour = GetClockHours(),
                    minute = GetClockMinutes()
                }
            end
            
            if currentTime.hour ~= lastTime.hour or currentTime.minute ~= lastTime.minute then
                lastTime.hour = currentTime.hour
                lastTime.minute = currentTime.minute
                SendReactMessage("updateTime", currentTime)
            end
        end
        
        local serviceBars = GetServiceBars()
        if lastService ~= serviceBars then
            lastService = serviceBars
            SendReactMessage("updateService", serviceBars)
        end
        
        Wait(1000)
    end
end)

function GetConfigFile(fileName)
    return LoadResourceFile(GetCurrentResourceName(), "config/" .. fileName)
end

RegisterNUICallback("getConfigFile", function(fileName, cb)
    local fileContent = GetConfigFile(fileName .. ".json")
    local decodedContent = json.decode(fileContent)
    cb(decodedContent)
end)

RegisterNetEvent("phone:logoutFromApp", function(data)
    debugprint("logoutFromApp:", data)
    
    if data.number and data.number == currentPhone then
        return debugprint("Ignoring logoutFromApp event since number matches")
    end
    
    debugprint(data.app .. ":logout", data.username)
    SendReactMessage(data.app .. ":logout", data.username)
end)

local nearbyPlayers = {}

function GetNearbyPlayers()
    return nearbyPlayers
end

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local allPlayers = GetActivePlayers()
        local nearby = {}
        
        for i = 1, #allPlayers do
            local player = allPlayers[i]
            if player ~= PlayerId() then
                local playerPed = GetPlayerPed(player)
                local pedCoords = GetEntityCoords(playerPed)
                local distance = #(playerCoords - pedCoords)
                
                if distance <= 60.0 then
                    table.insert(nearby, {
                        player = player,
                        source = GetPlayerServerId(player),
                        ped = playerPed
                    })
                end
            end
        end
        
        nearbyPlayers = nearby
        Wait(5000)
    end
end)

function LogOut()
    debugprint("LogOut triggered")
    
    while fetchingPhone do
        debugprint("LogOut triggered, waiting for fetchingPhone to finish...")
        Wait(500)
    end
    
    AwaitCallback("setLastPhone")
    
    phoneData = nil
    currentPhone = nil
    settings = nil
    
    TriggerEvent("lb-phone:numberChanged", nil)
    ResetSecurity()
    OnDeath()
end

function SetPhone(phoneNumber, skipFetch)
    debugprint("SetPhone triggered", phoneNumber, skipFetch)
    
    while fetchingPhone do
        debugprint("SetPhone triggered, waiting for fetchingPhone to finish...")
        Wait(500)
    end
    
    OnDeath()
    AwaitCallback("setLastPhone", phoneNumber)
    ResetSecurity(true)
    ToggleCharging(false)
    
    phoneData = nil
    currentPhone = nil
    settings = nil
    
    TriggerEvent("lb-phone:numberChanged", nil)
    
    if phoneNumber or skipFetch then
        FetchPhone()
    end
    
    if phoneNumber == nil and not skipFetch then
        local firstNumber = GetFirstNumber()
        if firstNumber then
            SetPhone(firstNumber)
        end
    end
end

function OnDeath()
    debugprint("OnDeath triggered")
    
    local liveData = IsWatchingLive()
    EndLive()
    if liveData then
        SendReactMessage("instagram:liveEnded", liveData)
    end
    
    if flashlightEnabled then
        flashlightEnabled = false
        TriggerServerEvent("phone:toggleFlashlight", false)
    end
    
    EndCall()
    
    if phoneOpen then
        ToggleOpen(false)
    end
end

RegisterNetEvent("phone:toggleOpen", ToggleOpen)

exports("ToggleOpen", ToggleOpen)
exports("IsOpen", function()
    return phoneOpen
end)
exports("IsDisabled", function()
    return phoneDisabled
end)
exports("ToggleDisabled", function(disabled)
    phoneDisabled = disabled == true
    debugprint("ToggleDisabled triggered", phoneDisabled)
    
    if phoneDisabled and phoneOpen then
        ToggleOpen(false)
    end
end)
exports("GetSettings", function()
    return settings
end)
exports("GetAirplaneMode", function()
    return settings and settings.airplaneMode
end)
exports("GetStreamerMode", function()
    return settings and settings.streamerMode
end)
exports("GetEquippedPhoneNumber", function()
    return currentPhone
end)