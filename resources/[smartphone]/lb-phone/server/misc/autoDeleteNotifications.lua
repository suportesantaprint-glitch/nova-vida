if not Config.AutoDeleteNotifications then
    return
end

if type(Config.AutoDeleteNotifications) ~= "number" then
    Config.AutoDeleteNotifications = 168
end

while true do
    if DatabaseCheckerFinished then
        break
    end
    Wait(500)
end

while true do
    debugprint("Deleting all old notifications..")
    local startTime = os.nanotime()
    
    MySQL.update(
        "DELETE FROM phone_notifications WHERE `timestamp` < DATE_SUB(NOW(), INTERVAL ? HOUR)",
        {Config.AutoDeleteNotifications},
        function(deletedCount)
            local endTime = os.nanotime()
            local executionTime = (endTime - startTime) / 10000.0
            local pluralSuffix = deletedCount == 1 and "" or "s"
            
            debugprint("Deleted " .. deletedCount .. " notification" .. pluralSuffix .. " in " .. executionTime .. " ms")
        end
    )
    
    Wait(360000)
end