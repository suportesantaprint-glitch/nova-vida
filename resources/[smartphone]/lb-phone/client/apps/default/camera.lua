cameraOpen = false
local isSelfieMode = false
local isVideoMode = false
local isHudHidden = false
local recordingPeerId = nil
local baseUrl = nil
local albumTypes = {
    selfies = "selfie",
    screenshots = "screenshot",
    imports = "import"
}

local function initializeMobileCamera()
    CreateMobilePhone(0)
    CellCamActivate(true, true)
    Citizen.InvokeNative(2635073306796480568, isSelfieMode)
    
    SetTimeout(500, function()
        local objects = GetGamePool("CObject")
        local playerCoords = GetEntityCoords(PlayerPedId())
        
        for i = 1, #objects do
            local object = objects[i]
            local objectCoords = GetEntityCoords(object)
            local distance = #(playerCoords - objectCoords)
            
            if distance < 4.0 then
                local model = GetEntityModel(object)
                if model == 413312110 then
                    SetEntityAsMissionEntity(object, true, true)
                    DeleteObject(object)
                end
            end
        end
    end)
    
    while phoneOpen and cameraOpen and not IsWalkingCamEnabled() do
        Wait(250)
        InvalidateIdleCam()
        InvalidateVehicleIdleCam()
    end
    
    DestroyMobilePhone()
    
    if cameraOpen and not IsWalkingCamEnabled() then
        while not phoneOpen do
            Wait(500)
        end
        initializeMobileCamera()
    end
end

local function showCameraTips()
    if isHudHidden or Config.Camera.ShowTip == false then
        return
    end
    
    local tips = {}
    
    if Config.KeyBinds.TakePhoto and Config.KeyBinds.TakePhoto.Command then
        table.insert(tips, L("BACKEND.CAMERA.TAKE_PHOTO", {key = Config.KeyBinds.TakePhoto.bindData.instructional}))
    end
    
    if Config.KeyBinds.FlipCamera and Config.KeyBinds.FlipCamera.Command then
        table.insert(tips, L("BACKEND.CAMERA.FLIP_CAMERA", {key = Config.KeyBinds.FlipCamera.bindData.instructional}))
    end
    
    if Config.KeyBinds.ToggleFlash and Config.KeyBinds.ToggleFlash.Command then
        table.insert(tips, L("BACKEND.CAMERA.TOGGLE_FLASH", {key = Config.KeyBinds.ToggleFlash.bindData.instructional}))
    end
    
    if Config.KeyBinds.LeftMode and Config.KeyBinds.LeftMode.Command and Config.KeyBinds.RightMode and Config.KeyBinds.RightMode.Command then
        table.insert(tips, L("BACKEND.CAMERA.CHANGE_MODE", {
            key = Config.KeyBinds.LeftMode.bindData.instructional,
            key2 = Config.KeyBinds.RightMode.bindData.instructional
        }))
    end
    
    if Config.KeyBinds.RollLeft and Config.KeyBinds.RollLeft.Command and Config.KeyBinds.RollRight and Config.KeyBinds.RollRight.Command then
        table.insert(tips, L("BACKEND.CAMERA.ROLL", {
            key = Config.KeyBinds.RollLeft.bindData.instructional,
            key2 = Config.KeyBinds.RollRight.bindData.instructional
        }))
    end
    
    if Config.Camera.Freeze and Config.Camera.Freeze.Enabled and Config.KeyBinds.FreezeCamera and Config.KeyBinds.FreezeCamera.Command then
        table.insert(tips, L("BACKEND.CAMERA.FREEZE", {key = Config.KeyBinds.FreezeCamera.bindData.instructional}))
    end
    
    if Config.KeyBinds.Focus and Config.KeyBinds.Focus.Command then
        table.insert(tips, L("BACKEND.CAMERA.TOGGLE_CURSOR", {key = Config.KeyBinds.Focus.bindData.instructional}))
    end
    
    if #tips > 0 then
        local tipText = table.concat(tips, "\n")
        AddTextEntry("CAMERA_TIP2", tipText)
        BeginTextCommandDisplayHelp("CAMERA_TIP2")
        EndTextCommandDisplayHelp(0, true, true, 0)
    end
end

local function processImageFilter(filter)
    if filter.album == "recents" then
        filter.album = nil
    elseif filter.album == "favourites" then
        filter.album = nil
        filter.favourites = true
    end
    
    if filter.type == "videos" then
        filter = {showPhotos = false, showVideos = true}
    end
    
    if filter.type then
        filter.album = nil
        local albumType = albumTypes[filter.type]
        if albumType then
            filter.type = albumType
        else
            filter.type = nil
            filter.duplicates = true
        end
    end
    
    if not filter.showPhotos and not filter.showVideos then
        filter.showPhotos = true
        filter.showVideos = true
    end
    
    return filter
end

local function getUploadMethod(uploadType)
    local uploadMethod
    
    if CustomGetUploadMethod then
        uploadMethod = CustomGetUploadMethod(uploadType)
    else
        local methodConfig = UploadMethods[Config.UploadMethod[uploadType]]
        if not methodConfig then
            infoprint("error", "Upload methods not found for " .. uploadType)
            return
        end
        
        uploadMethod = methodConfig[uploadType] or methodConfig.Default
        if not uploadMethod then
            infoprint("error", "Upload method not found for " .. uploadType)
            return
        end
    end
    
    if not uploadMethod.method then
        uploadMethod.method = Config.UploadMethod[uploadType]
    end
    
    if uploadMethod.sendPlayer and not uploadMethod.player then
        uploadMethod.player = {
            identifier = GetIdentifier(),
            name = GetPlayerName(PlayerId())
        }
    end
    
    if uploadMethod.url:find("BASE_URL") then
        if not baseUrl then
            baseUrl = AwaitCallback("camera:getBaseUrl")
        end
        uploadMethod.url = uploadMethod.url:gsub("BASE_URL", baseUrl)
    end
    
    local needsApiKey = uploadMethod.url:find("API_KEY")
    if uploadMethod.headers then
        for _, header in pairs(uploadMethod.headers) do
            if header:find("API_KEY") then
                needsApiKey = true
                break
            end
        end
    end
    
    if needsApiKey then
        local apiKey = AwaitCallback("camera:getUploadApiKey", uploadType)
        uploadMethod.url = uploadMethod.url:gsub("API_KEY", apiKey)
        
        if uploadMethod.headers then
            for key, value in pairs(uploadMethod.headers) do
                uploadMethod.headers[key] = value:gsub("API_KEY", apiKey)
            end
        end
    end
    
    if uploadMethod.url:find("PRESIGNED_URL") then
        local presignedUrl = AwaitCallback("camera:getPresignedUrl", uploadType)
        if not presignedUrl then
            infoprint("error", "Failed to get presigned url for " .. uploadType)
            return
        end
        uploadMethod.presignedUrl = uploadMethod.url:gsub("PRESIGNED_URL", presignedUrl)
    end
    
    return uploadMethod
end

RegisterNUICallback("Camera", function(data, callback)
    if not currentPhone or not data then
        return debugprint("Camera data is nil")
    end
    
    local action = data.action
    debugprint("Camera:" .. (action or ""))
    
    if action == "open" then
        callback("ok")
        cameraOpen = true
        showCameraTips()
        
        if Config.Camera.Enabled then
            EnableWalkableCam()
        else
            initializeMobileCamera()
        end
    elseif action == "saveToGallery" then
        TriggerCallback("camera:saveToGallery", callback, data.link, data.size, data.isVideo == true, data.type, data.shouldLog)
    elseif action == "deleteFromGallery" then
        if type(data.ids) ~= "table" then
            data.ids = {data.ids}
        end
        TriggerCallback("camera:deleteFromGallery", callback, data.ids)
    elseif action == "getLastImage" then
        TriggerCallback("camera:getLastImage", callback)
    elseif action == "getImages" then
        local filter = processImageFilter(data.filter or {})
        local images = AwaitCallback("camera:getImages", filter, data.page or 0)
        local processedImages = {}
        
        for i = 1, #images do
            local image = images[i]
            processedImages[i] = {
                id = image.id,
                src = image.link,
                isVideo = image.is_video,
                type = image.metadata,
                favourite = image.is_favourite,
                timestamp = image.timestamp,
                size = image.size or 0
            }
        end
        
        callback(processedImages)
    elseif action == "getAlbums" then
        TriggerCallback("camera:getHomePageData", callback)
    elseif action == "createAlbum" then
        TriggerCallback("camera:createAlbum", callback, data.title)
    elseif action == "renameAlbum" then
        TriggerCallback("camera:renameAlbum", callback, data.id, data.title)
    elseif action == "addToAlbum" then
        TriggerCallback("camera:addToAlbum", callback, data.album, data.ids)
    elseif action == "removeFromAlbum" then
        TriggerCallback("camera:removeFromAlbum", callback, data.album, data.ids)
    elseif action == "deleteAlbum" then
        TriggerCallback("camera:deleteAlbum", callback, data.id)
    elseif action == "removeMemberFromAlbum" then
        TriggerCallback("camera:removeMemberFromAlbum", callback, data.number, data.album)
    elseif action == "leaveSharedAlbum" then
        TriggerCallback("camera:leaveSharedAlbum", callback, data.id)
    elseif action == "getAlbumMembers" then
        TriggerCallback("camera:getAlbumMembers", callback, data.id)
    elseif action == "toggleFavourites" then
        TriggerCallback("camera:toggleFavourites", callback, data.favourite, data.ids)
    elseif action == "toggleVideo" then
        if isVideoMode == data.toggled then
            return callback("ok")
        end
        
        isVideoMode = data.toggled
        cameraOpen = true
        callback("ok")
        SendReactMessage("camera:toggleMicrophone", IsTalking())
        
        if not isVideoMode and Config.Camera.Enabled then
            EnableWalkableCam(isSelfieMode)
        else
            DisableWalkableCam()
            initializeMobileCamera()
        end
    elseif action == "toggleHud" then
        isHudHidden = not data.toggled
        TriggerEvent("lb-phone:toggleHud", isHudHidden)
        
        SetTimeout(100, function()
            callback(true)
        end)
        
        while isHudHidden do
            Wait(0)
            HideHudComponents()
        end
    elseif action == "getUploadApi" then
        callback(getUploadMethod(data.uploadType) or false)
    elseif action == "toggleLandscape" then
        local phoneObject = GetPhoneObject()
        local playerPed = PlayerPedId()
        
        if not DoesEntityExist(phoneObject) then
            return
        end
        
        local boneIndex = GetPedBoneIndex(playerPed, 28422)
        
        if data.toggled then
            AttachEntityToEntity(phoneObject, playerPed, boneIndex, -0.03, -0.005, -0.02, 0.0, 90.0, 180.0, false, false, false, false, 2, true)
        else
            AttachEntityToEntity(phoneObject, playerPed, boneIndex, 0.0, -0.005, 0.0, 0.0, 0.0, 180.0, false, false, false, false, 2, true)
        end
        
        callback("ok")
    elseif action == "flipCamera" then
        data.value = data.value == true
        
        if isSelfieMode == data.value then
            return callback("ok")
        end
        
        isSelfieMode = data.value
        
        if IsWalkingCamEnabled() then
            ToggleSelfieCam(isSelfieMode)
        else
            Citizen.InvokeNative(2635073306796480568, isSelfieMode)
        end
        
        callback("ok")
    elseif action == "setQuickZoom" then
        if IsWalkingCamEnabled() then
            SetCameraZoom(data.value)
        end
        callback(true)
    elseif action == "setRecordingPeerId" then
        TriggerServerEvent("phone:camera:setPeer", data.peerId)
        recordingPeerId = data.peerId
        callback("ok")
    elseif action == "endedRecording" then
        if recordingPeerId then
            TriggerServerEvent("phone:camera:endedRecording", recordingPeerId)
            recordingPeerId = nil
            callback("ok")
        end
    elseif action == "close" then
        cameraOpen = false
        isVideoMode = false
        isSelfieMode = false
        
        ClearAllHelpMessages()
        ClearHelp(true)
        DisableWalkableCam()
        callback("ok")
    end
end)

exports("SaveToGallery", function(link)
    assert(type(link) == "string", "Expected string for link, got " .. type(link))
    SendReactMessage("saveMedia", link)
end)

RegisterNetEvent("phone:photos:addMemberToAlbum", function(albumId, phoneNumber)
    SendReactMessage("photos:addMemberToAlbum", {
        albumId = albumId,
        phoneNumber = phoneNumber
    })
end)

RegisterNetEvent("phone:photos:removeMemberFromAlbum", function(albumId, phoneNumber)
    SendReactMessage("photos:removeMemberFromAlbum", {
        albumId = albumId,
        phoneNumber = phoneNumber
    })
end)

RegisterNetEvent("phone:photos:addSharedAlbum", function(albumData)
    SendReactMessage("photos:addSharedAlbum", albumData)
end)

RegisterNetEvent("phone:photos:updateAlbum", function(albumData)
    debugprint("phone:photos:updateAlbum", albumData)
    SendReactMessage("photos:updateAlbum", albumData)
end)