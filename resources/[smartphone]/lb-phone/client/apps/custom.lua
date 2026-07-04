local callbacks = {}
local validColors = {
    blue = true,
    red = true,
    green = true,
    yellow = true
}

local function generateUniqueId()
    local id = math.random(9999)
    while callbacks[id] do
        id = math.random(9999)
    end
    return id
end

RegisterNUICallback("CustomApp", function(data, cb)
    local appName = data.app
    local action = data.action
    
    cb("ok")
    
    if not action or not appName then
        debugprint("invalid data")
        return
    end
    
    local appConfig = Config.CustomApps[appName]
    
    if action == "open" then
        if appConfig and appConfig.onServerUse then
            TriggerServerEvent("lb-phone:customApp", appName)
        end
        
        if not (appConfig and appConfig.ui) then
            if not (appConfig and appConfig.keepOpen) then
                debugprint("Closing phone due to custom app without ui")
                ToggleOpen(false)
            end
        end
        
        if appConfig and appConfig.onUse then
            Citizen.CreateThreadNow(function()
                appConfig.onUse()
            end)
        end
        
        if appConfig and appConfig.onOpen then
            Citizen.CreateThreadNow(function()
                appConfig.onOpen()
            end)
        end
    elseif action == "close" then
        if appConfig and appConfig.onClose then
            appConfig.onClose()
        end
    elseif action == "install" then
        if appConfig and appConfig.onInstall then
            appConfig.onInstall()
        end
    elseif action == "uninstall" then
        if appConfig and appConfig.onDelete then
            appConfig.onDelete()
        end
    end
end)

RegisterNUICallback("PopUp", function(id, cb)
    local callback = callbacks[id]
    if not callback then
        return
    end
    
    cb("ok")
    callback()
    callbacks[id] = nil
end)

RegisterNUICallback("PopUpInputChanged", function(data, cb)
    local id = data.id
    local value = data.value
    local callback = callbacks[id]
    
    if not callback then
        return
    end
    
    cb("ok")
    callback(value)
end)

local function setupPopup(popupData, isExport)
    assert(popupData.buttons and #popupData.buttons > 0, "You need at least one button")
    
    for _, button in pairs(popupData.buttons) do
        assert(button.title, "You need a title for each button")
        assert(validColors[button.color or "blue"], "Invalid color")
        
        if isExport == true then
            if button.cb then
                local callbackId = generateUniqueId()
                local originalCallback = button.cb
                callbacks[callbackId] = function()
                    originalCallback(button.callbackId)
                end
                button.cb = callbackId
            end
        else
            if button.callbackId then
                local callbackId = generateUniqueId()
                callbacks[callbackId] = function()
                    isExport(button.callbackId)
                end
                button.cb = callbackId
            end
        end
    end
    
    local inputData = popupData.input
    if inputData and inputData.onChange then
        local inputCallbackId = generateUniqueId()
        
        if isExport == true then
            callbacks[inputCallbackId] = inputData.onChange
        else
            callbacks[inputCallbackId] = function(value)
                SendReactMessage("customApp:sendMessage", {
                    identifier = "any",
                    message = {
                        type = "popUpInputChanged",
                        value = value
                    }
                })
            end
        end
        inputData.onChange = inputCallbackId
    end
    
    SendReactMessage("onComponentUse", {
        type = "popup",
        data = popupData
    })
end

RegisterNUICallback("SetPopUp", setupPopup)

exports("SetPopUp", function(popupData)
    setupPopup(popupData, true)
end)

RegisterNUICallback("ContextMenu", function(id, cb)
    local callback = callbacks[id]
    if not callback then
        return
    end
    
    callback()
    callbacks[id] = nil
    cb("ok")
end)

local function setupContextMenu(menuData, isExport)
    assert(menuData.buttons and #menuData.buttons > 0, "You need at least one button")
    
    for _, button in pairs(menuData.buttons) do
        assert(button.title, "You need a title for each button")
        assert(validColors[button.color or "blue"], "Invalid colour")
        
        if isExport == true then
            assert(button.cb, "You need a callback for each button")
        else
            assert(button.callbackId, "You need a callback for each button")
        end
        
        local callbackId = generateUniqueId()
        local originalCallback = button.cb
        
        callbacks[callbackId] = function()
            if isExport == true then
                originalCallback()
            else
                isExport(button.callbackId)
            end
        end
        button.cb = callbackId
    end
    
    SendReactMessage("onComponentUse", {
        type = "contextmenu",
        data = menuData
    })
end

RegisterNUICallback("SetContextMenu", setupContextMenu)

exports("SetContextMenu", function(menuData)
    setupContextMenu(menuData, true)
end)

local function setupCameraComponent(cameraData, callback)
    if type(cameraData) ~= "table" or not cameraData then
        cameraData = {}
    end
    
    local promise = nil
    local wasPhoneOpen = phoneOpen
    local componentId = generateUniqueId()
    cameraData.id = componentId
    
    if not wasPhoneOpen then
        debugprint("Opening phone due to camera component")
        ToggleOpen(true)
    end
    
    if not callback then
        promise = promise.new()
    end
    
    callbacks[componentId] = function(result)
        if callback then
            callback(result.url)
        else
            promise:resolve(result.url)
        end
        
        if not wasPhoneOpen then
            debugprint("Closing phone due to camera component")
            ToggleOpen(false)
        end
    end
    
    SendReactMessage("onComponentUse", {
        type = "camera",
        data = cameraData
    })
    
    if not callback then
        return Citizen.Await(promise)
    end
end

exports("SetCameraComponent", setupCameraComponent)

local function setupContactModal(phoneNumber)
    assert(phoneNumber, "You need to provide a phone number")
    SendReactMessage("onComponentUse", {
        type = "contactmodal",
        data = phoneNumber
    })
end

RegisterNUICallback("SetContactModal", function(data, cb)
    setupContactModal(data)
    cb("ok")
end)

exports("SetContactModal", setupContactModal)

local componentTypes = {
    gallery = {"image"},
    gif = {"gif"},
    emoji = {"emoji"},
    camera = {"url"},
    colorpicker = {"color"},
    contactselector = {"contact"}
}

RegisterNUICallback("UsedComponent", function(data, cb)
    local componentId = data and data.id
    if not componentId or not callbacks[componentId] then
        return
    end
    
    callbacks[componentId](data)
    callbacks[componentId] = nil
    cb("ok")
end)

local function showComponent(componentData, callback)
    local componentType = componentData.component
    assert(componentType, "You need to specify a component")
    assert(componentTypes[componentType], "Invalid component")
    
    local componentId = generateUniqueId()
    
    callbacks[componentId] = function(result)
        local values = {}
        for _, key in pairs(componentTypes[componentType]) do
            table.insert(values, result[key])
        end
        callback(table.unpack(values))
    end
    
    componentData.id = componentId
    SendReactMessage("onComponentUse", {
        type = componentType,
        data = componentData
    })
end

RegisterNUICallback("ShowComponent", showComponent)
exports("ShowComponent", showComponent)

RegisterNUICallback("CreateCall", function(data, cb)
    CreateCall(data)
    cb("ok")
end)

RegisterNUICallback("GetSettings", function(data, cb)
    cb(settings)
end)

RegisterNUICallback("GetLocale", function(data, cb)
    cb(L(data.path, data.format))
end)

RegisterNUICallback("SendNotification", function(data, cb)
    if data and data.customData and data.customData.buttons then
        data.customData.buttons = nil
        debugprint("You cannot create notifications with buttons from the NUI.")
    end
    
    TriggerEvent("phone:sendNotification", data)
    cb(true)
end)