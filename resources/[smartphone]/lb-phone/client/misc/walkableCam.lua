local maxFOV = Config.Camera and Config.Camera.MaxFOV or 70.0
local defaultFOV = Config.Camera and Config.Camera.DefaultFOV or 60.0
local minFOV = Config.Camera and Config.Camera.MinFOV or 10.0
local maxLookUp = Config.Camera and Config.Camera.MaxLookUp or 80.0
local maxLookDown = Config.Camera and Config.Camera.MaxLookDown or -80.0
local allowRunning = Config.Camera and Config.Camera.AllowRunning == true

local vehicleZoomEnabled = Config.Camera and Config.Camera.Vehicle and Config.Camera.Vehicle.Zoom == true
local vehicleMaxFOV = Config.Camera and Config.Camera.Vehicle and Config.Camera.Vehicle.MaxFOV or 80.0
local vehicleDefaultFOV = Config.Camera and Config.Camera.Vehicle and Config.Camera.Vehicle.DefaultFOV or 60.0
local vehicleMinFOV = Config.Camera and Config.Camera.Vehicle and Config.Camera.Vehicle.MinFOV or 10.0
local vehicleMaxLookUp = Config.Camera and Config.Camera.Vehicle and Config.Camera.Vehicle.MaxLookUp or 50.0
local vehicleMaxLookDown = Config.Camera and Config.Camera.Vehicle and Config.Camera.Vehicle.MaxLookDown or -30.0
local vehicleMaxLeftRight = Config.Camera and Config.Camera.Vehicle and Config.Camera.Vehicle.MaxLeftRight or 120.0
local vehicleMinLeftRight = Config.Camera and Config.Camera.Vehicle and Config.Camera.Vehicle.MinLeftRight or -120.0

local selfieMaxFOV = Config.Camera and Config.Camera.Selfie and Config.Camera.Selfie.MaxFOV or 80.0
local selfieDefaultFOV = Config.Camera and Config.Camera.Selfie and Config.Camera.Selfie.DefaultFOV or 60.0
local selfieMinFOV = Config.Camera and Config.Camera.Selfie and Config.Camera.Selfie.MinFOV or 50.0

local freezeEnabled = Config.Camera and Config.Camera.Freeze and Config.Camera.Freeze.Enabled == true
local freezeMaxDistance = Config.Camera and Config.Camera.Freeze and Config.Camera.Freeze.MaxDistance or 10.0
local freezeMaxTime = (Config.Camera and Config.Camera.Freeze and Config.Camera.Freeze.MaxTime or 60) * 1000

local selfieOffset = Config.Camera and Config.Camera.Selfie and Config.Camera.Selfie.Offset or vector3(0.1, 0.55, 0.6)
local selfieRotation = Config.Camera and Config.Camera.Selfie and Config.Camera.Selfie.Rotation or vector3(10.0, 0.0, -180.0)
local rollEnabled = Config.Camera and Config.Camera.Roll == true

local cameraOffset = vector3(0.0, 0.5, 0.6)
local pitchAngle = 0.0
local rollAngle = 0.0
local currentFOV = 60.0
local originalViewMode = 0
local vehicleYawAngle = 0.0
local isMoving = false
local isFrozen = false
local freezeEndTime = 0
local playerPed = PlayerPedId()
local isSelfieMode = false
local isWalking = false
local sensitivity = 0.0
local mouseSensitivity = GetProfileSetting(754) + 10
local currentZoom = 1.0
local camera = nil

local CameraMode = {
    REAR = 0,
    SELFIE = 1,
    IN_VEHICLE = 2
}

local currentMode = CameraMode.REAR

local function getCameraLimits()
    local inVehicle = IsPedInAnyVehicle(playerPed, true)
    
    local maxFov = isSelfieMode and selfieMaxFOV or (inVehicle and vehicleMaxFOV or maxFOV)
    local minFov = isSelfieMode and selfieMinFOV or (inVehicle and vehicleZoomEnabled and vehicleMinFOV or (inVehicle and vehicleMaxFOV or minFOV))
    local defaultFov = isSelfieMode and selfieDefaultFOV or (inVehicle and vehicleDefaultFOV or defaultFOV)
    
    return maxFov, minFov, defaultFov
end

function ConvertFovToZoom(fov)
    local maxFov, minFov, defaultFov = getCameraLimits()
    local clampedFov = math.clamp(fov, minFov, maxFov)
    
    if clampedFov == defaultFov then
        return 1.0
    elseif defaultFov > clampedFov then
        if clampedFov <= 0 then
            return 1.0
        end
        return defaultFov / clampedFov
    else
        local ratio = (clampedFov - defaultFov) / (maxFov - defaultFov)
        return 1.0 - (ratio * 0.5)
    end
end

local function convertZoomToFov(zoom)
    local maxFov, minFov, defaultFov = getCameraLimits()
    local maxZoom = 1.0
    
    if defaultFov < maxFov then
        maxZoom = 0.5
    end
    
    local minZoom = 1.0
    if minFov < defaultFov and minFov > 0 then
        minZoom = defaultFov / minFov
    end
    
    local clampedZoom = math.clamp(zoom, maxZoom, minZoom)
    
    if clampedZoom == 1.0 then
        return defaultFov
    elseif clampedZoom > 1.0 then
        return defaultFov / clampedZoom
    else
        local ratio = (1.0 - clampedZoom) * 2.0
        return defaultFov + (ratio * (maxFov - defaultFov))
    end
end

local function updateZoomLevels()
    local maxFov, minFov, defaultFov = getCameraLimits()
    local maxZoom = ConvertFovToZoom(maxFov)
    local minZoom = ConvertFovToZoom(minFov)
    
    local zoomLevels = {1.0}
    
    if maxZoom < 1.0 then
        table.insert(zoomLevels, 1, maxZoom)
    end
    
    if minZoom > 2.0 then
        table.insert(zoomLevels, 2)
    end
    
    if minZoom > 5.0 then
        table.insert(zoomLevels, 5)
    elseif minZoom > 3.0 then
        table.insert(zoomLevels, 3)
    end
    
    SendReactMessage("camera:setZoomLevels", zoomLevels)
end

function SetCameraZoom(zoom)
    currentFOV = convertZoomToFov(zoom)
end

local function handleCameraControls()
    local inVehicle = IsPedInAnyVehicle(playerPed, true)
    local newMode = isSelfieMode and CameraMode.SELFIE or CameraMode.REAR
    
    if inVehicle then
        newMode = newMode | CameraMode.IN_VEHICLE
    end
    
    if currentMode ~= newMode then
        local maxFov, minFov, defaultFov = getCameraLimits()
        currentMode = newMode
        currentFOV = defaultFov
        
        debugprint("Camera mode changed to: " .. currentMode)
        updateZoomLevels()
        SetCamFov(camera, currentFOV)
    end
    
    isWalking = IsDisabledControlPressed(0, 33) or IsDisabledControlPressed(0, 34) or 
               (IsDisabledControlPressed(0, 35) and not inVehicle)
    
    SetFollowPedCamViewMode(0)
    SetGameplayCamRelativeHeading(0.0)
    
    DisableControlAction(0, 1, true)
    DisableControlAction(0, 14, true)
    DisableControlAction(0, 15, true)
    DisableControlAction(0, 16, true)
    DisableControlAction(0, 17, true)
    DisableControlAction(0, 99, true)
    DisableControlAction(0, 100, true)
    DisableControlAction(0, 115, true)
    DisableControlAction(0, 116, true)
    DisableControlAction(0, 261, true)
    DisableControlAction(0, 262, true)
    
    SetPedResetFlag(playerPed, 47, true)
    
    if isFrozen and not inVehicle then
        local playerCoords = GetEntityCoords(playerPed)
        local cameraCoords = GetCamCoord(camera)
        local distance = #(playerCoords - cameraCoords)
        
        if distance > freezeMaxDistance or GetGameTimer() > freezeEndTime then
            isFrozen = false
            TogglePhoneAnimation(true, "camera")
        end
        return
    end
    
    if not allowRunning then
        DisableControlAction(0, 21, true)
    end
    
    if isSelfieMode and not inVehicle then
        AttachCamToPedBone_2(camera, playerPed, 0, 
            selfieRotation.x + pitchAngle, selfieRotation.y, selfieRotation.z,
            selfieOffset.x, selfieOffset.y, selfieOffset.z, true)
    elseif not isSelfieMode and not inVehicle then
        local cameraCoords = GetOffsetFromEntityInWorldCoords(playerPed, cameraOffset.x, cameraOffset.y, cameraOffset.z)
        local headCoords = GetPedBoneCoords(playerPed, 31086, 0.0, 0.0, 0.0)
        
        local zCoord = math.abs(headCoords.z - cameraCoords.z) > 0.2 and headCoords.z or cameraCoords.z
        
        DetachCam(camera)
        SetCamCoord(camera, cameraCoords.x, cameraCoords.y, zCoord)
        SetCamRot(camera, pitchAngle, rollAngle, GetEntityHeading(playerPed), 2)
    elseif isSelfieMode and inVehicle then
        AttachCamToPedBone_2(camera, playerPed, 0,
            80.0 + pitchAngle, 0.0, -180.0,
            0.0, 0.2, 0.5, true)
    elseif not isSelfieMode and inVehicle then
        SetEntityLocallyInvisible(GetPhoneObject())
        SetEntityLocallyInvisible(playerPed)
        
        AttachCamToPedBone_2(camera, playerPed, GetPedBoneIndex(playerPed, 11816),
            pitchAngle, 0.0, vehicleYawAngle,
            0.0, 0.0, 0.55, true)
    end
    
    if inVehicle then
        if not isMoving then
            isMoving = true
            SetUserRadioControlEnabled(false)
        end
    else
        if isMoving then
            isMoving = false
            SetUserRadioControlEnabled(true)
        end
        vehicleYawAngle = 0.0
    end
    
    if isWalking then
        SetPedResetFlag(playerPed, 69, true)
    elseif not isSelfieMode and not inVehicle then
        DisableControlAction(0, 30, true)
    end
    
    local currentCamFov = GetCamFov(camera)
    local maxFov, minFov, defaultFov = getCameraLimits()
    
    currentFOV = math.clamp(currentFOV, minFov, maxFov)
    
    local newZoom = math.round(ConvertFovToZoom(currentCamFov), 1)
    if newZoom ~= currentZoom then
        debugprint("Zoom changed to: " .. newZoom, ConvertFovToZoom(currentCamFov), currentCamFov)
        currentZoom = newZoom
        SendReactMessage("camera:setZoom", newZoom)
    end
    
    if math.abs(currentFOV - currentCamFov) > 0.05 then
        SetCamFov(camera, currentCamFov + ((currentFOV - currentCamFov) / 25))
    end
    
    if IsNuiFocused() then
        return
    end
    
    sensitivity = mouseSensitivity * (currentFOV / maxFOV) / 5
    
    local leftStickX = GetDisabledControlNormal(0, 1)
    
    if inVehicle then
        vehicleYawAngle = math.clamp(vehicleYawAngle - (leftStickX * sensitivity), vehicleMinLeftRight, vehicleMaxLeftRight)
    elseif leftStickX ~= 0.0 then
        SetEntityHeading(playerPed, GetEntityHeading(playerPed) - (leftStickX * sensitivity))
    end
    
    if IsDisabledControlPressed(0, 180) then
        currentFOV = currentFOV + 5
    elseif IsDisabledControlPressed(0, 181) then
        currentFOV = currentFOV - 5
    end
    
    local leftStickY = GetDisabledControlNormal(0, 2)
    if leftStickY ~= 0.0 then
        local pitchChange = leftStickY * sensitivity
        
        if inVehicle then
            pitchAngle = math.clamp(pitchAngle - pitchChange, vehicleMaxLookDown, vehicleMaxLookUp)
        else
            pitchAngle = math.clamp(pitchAngle - pitchChange, maxLookDown, maxLookUp)
        end
    end
end

local function handleMovementControls()
    local leftStickX = GetDisabledControlNormal(0, 1)
    
    if leftStickX ~= 0.0 then
        SetEntityHeading(playerPed, GetEntityHeading(playerPed) - (leftStickX * sensitivity))
    end
end

function EnableWalkableCam(selfieMode)
    if camera then
        return
    end
    
    isSelfieMode = selfieMode == true
    isWalking = false
    currentFOV = isSelfieMode and selfieDefaultFOV or defaultFOV
    playerPed = PlayerPedId()
    originalViewMode = GetFollowPedCamViewMode()
    pitchAngle = 0.0
    vehicleYawAngle = 0.0
    rollAngle = 0.0
    isFrozen = false
    
    camera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    mouseSensitivity = GetProfileSetting(754) + 10
    currentZoom = 1.0
    
    SetPhoneAction("camera")
    
    CreateThread(function()
        while camera do
            Wait(0)
            
            if not isWalking and not isFrozen then
                if not IsNuiFocused() then
                    handleMovementControls()
                end
            end
        end
    end)
    
    CreateThread(function()
        while camera do
            Wait(0)
            handleCameraControls()
        end
        
        if isMoving then
            isMoving = false
            SetUserRadioControlEnabled(true)
        end
    end)
    
    SetCamFov(camera, currentFOV)
    RenderScriptCams(true, false, 0, true, true)
    SetCamActive(camera, true)
    SendReactMessage("camera:setZoom", 1.0)
    updateZoomLevels()
end

function DisableWalkableCam()
    if not camera then
        return
    end
    
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(camera, false)
    SetFollowPedCamViewMode(originalViewMode)
    SetPhoneAction(IsInCall() and "call" or "default")
    
    camera = nil
    
    if isFrozen then
        TogglePhoneAnimation(true, "camera")
    end
end

function ToggleSelfieCam(enabled)
    local wasSelfieModeEnabled = isSelfieMode
    isSelfieMode = enabled == true
    
    if wasSelfieModeEnabled ~= isSelfieMode then
        rollAngle = 0.0
        pitchAngle = 0.0
    end
end

function ToggleCameraFrozen()
    if not freezeEnabled or not camera or isSelfieMode then
        return
    end
    
    local newFrozenState = not isFrozen
    
    if newFrozenState then
        TogglePhoneAnimation(false, "camera")
        freezeEndTime = GetGameTimer() + freezeMaxTime
    end
    
    isFrozen = newFrozenState
end

function IsWalkingCamEnabled()
    return camera ~= nil
end

function IsSelfieCam()
    return isSelfieMode
end

AddEventHandler("lb-phone:keyPressed", function(key)
    if not camera then
        return
    end
    
    if key == "FreezeCamera" then
        if not freezeEnabled or isSelfieMode then
            return
        end
        ToggleCameraFrozen()
    elseif key == "RollLeft" or key == "RollRight" then
        if not rollEnabled then
            return
        end
        
        local rollDirection = key == "RollLeft" and -0.5 or 0.5
        local keyBind = Config.KeyBinds[key].bindData
        
        while keyBind.pressed do
            Wait(0)
            rollAngle = rollAngle + rollDirection
        end
    end
end)

exports("EnableWalkableCam", EnableWalkableCam)
exports("DisableWalkableCam", DisableWalkableCam)
exports("ToggleSelfieCam", ToggleSelfieCam)
exports("ToggleCameraFrozen", ToggleCameraFrozen)
exports("IsWalkingCamEnabled", IsWalkingCamEnabled)
exports("IsSelfieCam", IsSelfieCam)