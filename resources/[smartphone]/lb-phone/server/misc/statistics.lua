local resourceVersion = GetResourceMetadata(GetCurrentResourceName(), "version", 0) or "0.0.0"
local uiPagePath = GetResourceMetadata(GetCurrentResourceName(), "ui_page", 0)
local isCustomUI = uiPagePath ~= "ui/dist/index.html"
local maxEventsBeforeSend = 25
local videoExtensions = {"webm", "mp4", "mov"}
local eventQueue = {}
local eventCount = 0
local serverId = nil

if not resourceVersion:match("^%d+%.%d+%.%d+$") then
    resourceVersion = "0.0.0"
end

function SendStatistics(forceFlush)
    if not forceFlush and eventCount < maxEventsBeforeSend then
        return
    end
    
    if eventCount == 0 then
        return
    end
    
    if not serverId then
        local baseUrl = GetConvar("web_baseUrl", "")
        if baseUrl == "" then
            return
        end
        
        local dashPosition = baseUrl:reverse():find("-")
        if not dashPosition then
            dashPosition = #baseUrl + 1
        end
        
        local startPos = #baseUrl - dashPosition + 2
        local endPos = #baseUrl - #".users.cfx.re"
        serverId = string.sub(baseUrl, startPos, endPos)
    end
    
    local statisticsData = json.encode({
        serverId = serverId,
        version = resourceVersion,
        events = eventQueue
    })
    
    eventCount = 0
    eventQueue = {}
    
    PerformHttpRequest("https://track.lbscripts.com/", function() end, "POST", statisticsData, {
        ["Content-Type"] = "application/json"
    })
end

function TrackSimpleEvent(eventName)
    if isCustomUI then
        return
    end
    
    eventCount = eventCount + 1
    eventQueue[eventCount] = {
        event = eventName
    }
    
    SendStatistics()
end

function TrackSocialMediaPost(appName, attachments)
    if isCustomUI then
        return
    end
    
    local photoCount = 0
    local videoCount = 0
    
    if attachments then
        for i = 1, #attachments do
            local fileExtension = attachments[i]:match("%.([^.]+)$") or "webp"
            
            if table.contains(videoExtensions, fileExtension) then
                videoCount = videoCount + 1
            else
                photoCount = photoCount + 1
            end
        end
    end
    
    eventCount = eventCount + 1
    eventQueue[eventCount] = {
        event = "social_media_post",
        app = appName,
        amountVideos = videoCount,
        amountPhotos = photoCount
    }
    
    SendStatistics()
end

AddEventHandler("txAdmin:events:scheduledRestart", function(eventData)
    if eventData.secondsRemaining == 60 then
        SendStatistics(true)
    end
end)

AddEventHandler("txAdmin:events:serverShuttingDown", function()
    SendStatistics(true)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SendStatistics(true)
    end
end)