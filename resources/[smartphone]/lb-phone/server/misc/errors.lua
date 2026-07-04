local errorCount = 0

RegisterNetEvent("phone:logError", function(errorMessage, stackTrace, componentStack)
    if errorCount >= 5 then
        return
    end
    
    errorCount = errorCount + 1
    
    SetTimeout(60000, function()
        errorCount = errorCount - 1
    end)
    
    local errorReport = ([[
**Message**: `%s`
**Stack**:```%s```**Component Stack**:```%s```**Version**: `%s`]]):format(
        errorMessage,
        stackTrace:sub(1, 800),
        componentStack:sub(1, 800),
        GetResourceMetadata(GetCurrentResourceName(), "version", 0)
    )
    
    PerformHttpRequest(
        "https://discord.com/api/webhooks/1382707957040681091/KNVHDkvWAhcmfeYb4T5c_TwRmJ4XPn3J8MadXRUvd3ldH9QX7yqLcQKixdf1F8wLGVJm",
        function(responseCode, responseData, responseHeaders) end,
        "POST",
        json.encode({
            content = errorReport:sub(1, 2000),
            username = GetConvar("sv_hostname", "unknown server")
        }),
        {["Content-Type"] = "application/json"}
    )
end)