RegisterLegacyCallback("appstore:buyApp", function(source, callback, appPrice)
    local phoneNumber = GetEquippedPhoneNumber(source)
    
    if not phoneNumber then
        return callback(false)
    end
    
    local success, balance, newBalance = RemoveMoney(source, appPrice)
    callback(success, balance, newBalance)
end)