local cryptoConfig = Config.Crypto
local cryptoLimits = {}
local requestCount = 0
local cryptoData = {
    hasFetched = false,
    coins = {},
    customCoins = {}
}

if not cryptoConfig or not cryptoConfig.Enabled then
    debugprint("crypto disabled")
    return
end

if cryptoConfig and cryptoConfig.Limits then
    cryptoLimits = cryptoConfig.Limits
else
    cryptoLimits = {
        Buy = 10000,
        Sell = 10000
    }
end

local function makeApiRequest(endpoint)
    if requestCount >= 5 then
        return false
    end
    
    requestCount = requestCount + 1
    
    SetTimeout(60000, function()
        requestCount = requestCount - 1
    end)
    
    local promise = promise.new()
    local apiUrl = "https://api.coingecko.com/api/v3/" .. endpoint
    
    PerformHttpRequest(apiUrl, function(statusCode, responseData)
        local decodedData = false
        if responseData then
            local success, result = pcall(json.decode, responseData)
            if success then
                decodedData = result
            end
        end
        promise:resolve(decodedData)
    end, "GET", "", {
        ["Content-Type"] = "application/json"
    })
    
    return Citizen.Await(promise)
end

local coinIds = nil
if cryptoConfig.Coins and #cryptoConfig.Coins > 0 then
    coinIds = table.concat(cryptoConfig.Coins, ",")
end

local function fetchCryptoData()
    local lastFetched = GetResourceKvpInt("lb-phone:crypto:lastFetched") or 0
    local currentTime = os.time()
    local refreshInterval = cryptoConfig.Refresh / 1000
    
    if lastFetched > (currentTime - refreshInterval) then
        local cachedData = GetResourceKvpString("lb-phone:crypto:coins")
        if cachedData then
            cryptoData.coins = json.decode(cachedData)
            
            for coinId, coinData in pairs(cryptoData.customCoins) do
                cryptoData.coins[coinId] = coinData
            end
            
            debugprint("crypto: using kvp cache")
            return
        end
    end
    
    local apiData = {}
    if coinIds then
        local endpoint = "coins/markets?vs_currency=" .. cryptoConfig.Currency .. 
                        "&sparkline=true&order=market_cap_desc&precision=full&per_page=100&page=1&ids=" .. coinIds
        apiData = makeApiRequest(endpoint) or {}
    end
    
    if not apiData then
        debugprint("failed to fetch coins")
        return
    end
    
    for i = 1, #apiData do
        local coin = apiData[i]
        cryptoData.coins[coin.id] = {
            id = coin.id,
            name = coin.name,
            symbol = coin.symbol,
            image = coin.image,
            current_price = coin.current_price,
            prices = coin.sparkline_in_7d and coin.sparkline_in_7d.price or nil,
            change_24h = coin.price_change_percentage_24h
        }
    end
    
    for coinId, coinData in pairs(cryptoData.customCoins) do
        cryptoData.coins[coinId] = coinData
    end
    
    SetResourceKvpInt("lb-phone:crypto:lastFetched", os.time())
    SetResourceKvp("lb-phone:crypto:coins", json.encode(cryptoData.coins))
    
    debugprint("fetched coins")
end

CreateThread(function()
    while true do
        fetchCryptoData()
        cryptoData.hasFetched = true
        
        TriggerClientEvent("phone:crypto:updateCoins", -1, cryptoData.coins)
        
        Wait(cryptoConfig.Refresh)
    end
end)

local function updateCryptoInDatabase(playerId, coinId, amount, invested)
    invested = invested or 0
    
    MySQL.update.await(
        "INSERT INTO phone_crypto (id, coin, amount, invested) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount), invested = invested + VALUES(invested)",
        {playerId, coinId, amount, invested}
    )
end

RegisterCallback("crypto:get", function(source)
    local playerId = GetIdentifier(source)
    
    while not cryptoData.hasFetched or not DatabaseCheckerFinished do
        Wait(500)
    end
    
    local playerCrypto = MySQL.query.await(
        "SELECT coin, amount, invested FROM phone_crypto WHERE id = ?",
        {playerId}
    )
    
    local coinsList = table.deep_clone(cryptoData.coins)
    
    for i = 1, #playerCrypto do
        local crypto = playerCrypto[i]
        if crypto and coinsList[crypto.coin] then
            coinsList[crypto.coin].owned = crypto.amount
            coinsList[crypto.coin].invested = crypto.invested
        end
    end
    
    return coinsList
end)

RegisterCallback("crypto:buy", function(source, coinId, amount)
    local playerId = GetIdentifier(source)
    local playerBalance = GetBalance(source)
    
    if amount <= 0 then
        return {success = false, msg = "INVALID_AMOUNT"}
    end
    
    if amount > cryptoLimits.Buy then
        debugprint(amount, "is above crypto buy limit")
        return {success = false, msg = "INVALID_AMOUNT"}
    end
    
    if amount > playerBalance then
        return {success = false, msg = "NO_MONEY"}
    end
    
    local coinData = cryptoData.coins[coinId]
    if not coinData then
        return {success = false, msg = "INVALID_COIN"}
    end
    
    if not playerId then
        return {success = false, msg = "NO_IDENTIFIER"}
    end
    
    local coinAmount = amount / coinData.current_price
    
    updateCryptoInDatabase(playerId, coinId, coinAmount, amount)
    RemoveMoney(source, amount)
    
    Log("Crypto", source, "success", 
        L("BACKEND.LOGS.BOUGHT_CRYPTO"),
        L("BACKEND.LOGS.CRYPTO_DETAILS", {
            coin = coinId,
            amount = coinAmount,
            price = amount
        })
    )
    
    return {success = true}
end, {preventSpam = true})

RegisterCallback("crypto:sell", function(source, coinId, amount)
    local playerId = GetIdentifier(source)
    
    if amount <= 0 then
        return {success = false, msg = "INVALID_AMOUNT"}
    end
    
    local playerCrypto = MySQL.single.await(
        "SELECT amount, invested FROM phone_crypto WHERE id = ? AND coin = ?",
        {playerId, coinId}
    )
    
    if not playerCrypto then
        return {success = false, msg = "NO_COINS"}
    end
    
    if amount > playerCrypto.amount then
        return {success = false, msg = "NOT_ENOUGH_COINS"}
    end
    
    local coinData = cryptoData.coins[coinId]
    if not coinData then
        return {success = false, msg = "INVALID_COIN"}
    end
    
    local saleValue = amount * coinData.current_price
    
    if saleValue > cryptoLimits.Sell then
        debugprint(saleValue, "is above crypto sell limit")
        return {success = false, msg = "INVALID_AMOUNT"}
    end
    
    MySQL.update.await(
        "UPDATE phone_crypto SET amount = amount - ?, invested = invested - ? WHERE id = ? AND coin = ?",
        {amount, saleValue, playerId, coinId}
    )
    
    AddMoney(source, saleValue)
    
    Log("Crypto", source, "error", 
        L("BACKEND.LOGS.SOLD_CRYPTO"),
        L("BACKEND.LOGS.CRYPTO_DETAILS", {
            coin = coinId,
            amount = amount,
            price = saleValue
        })
    )
    
    return {success = true}
end, {preventSpam = true})

BaseCallback("crypto:transfer", function(source, fromNumber, coinId, amount, toNumber)
    local coinData = cryptoData.coins[coinId]
    if not coinData then
        return {success = false, msg = "INVALID_COIN"}
    end
    
    local targetSource = GetSourceFromNumber(toNumber)
    local targetId = nil
    
    if targetSource then
        targetId = GetIdentifier(targetSource)
    else
        if not Config.Item.Unique then
            targetId = MySQL.scalar.await(
                "SELECT id FROM phone_phones WHERE phone_number = ?",
                {toNumber}
            )
        else
            targetId = MySQL.scalar.await(
                "SELECT owned_id FROM phone_phones WHERE phone_number = ?",
                {toNumber}
            )
        end
    end
    
    if not targetId then
        return {success = false, msg = "INVALID_NUMBER"}
    end
    
    local senderId = GetIdentifier(source)
    
    if amount <= 0 then
        return {success = false, msg = "INVALID_AMOUNT"}
    end
    
    local senderAmount = MySQL.scalar.await(
        "SELECT amount FROM phone_crypto WHERE id = ? AND coin = ?",
        {senderId, coinId}
    ) or 0
    
    if amount > senderAmount then
        return {success = false, msg = "INVALID_AMOUNT"}
    end
    
    MySQL.update.await(
        "UPDATE phone_crypto SET amount = amount - ? WHERE id = ? AND coin = ?",
        {amount, senderId, coinId}
    )
    
    updateCryptoInDatabase(targetId, coinId, amount)
    
    local transferValue = math.floor(amount * coinData.current_price + 0.5)
    SendNotification(toNumber, {
        app = "Crypto",
        title = L("BACKEND.CRYPTO.RECEIVED_TRANSFER_TITLE", {coin = coinData.name}),
        content = L("BACKEND.CRYPTO.RECEIVED_TRANSFER_DESCRIPTION", {
            amount = amount,
            coin = coinData.name,
            value = transferValue
        })
    })
    
    Log("Crypto", source, "error", 
        L("BACKEND.LOGS.TRANSFERRED_CRYPTO"),
        L("BACKEND.LOGS.TRANSFERRED_CRYPTO_DETAILS", {
            coin = coinId,
            amount = amount,
            to = toNumber,
            from = fromNumber
        })
    )
    
    if targetSource then
        TriggerClientEvent("phone:crypto:changeOwnedAmount", targetSource, coinId, amount)
    end
    
    return {success = true}
end, {preventSpam = true})

exports("AddCrypto", function(source, coinId, amount)
    local playerId = GetIdentifier(source)
    
    if not cryptoData.coins[coinId] then
        print("invalid coin", coinId)
        return false
    end
    
    if not playerId then
        print("no identifier")
        return false
    end
    
    updateCryptoInDatabase(playerId, coinId, amount)
    
    TriggerClientEvent("phone:crypto:changeOwnedAmount", source, coinId, amount)
    
    return true
end)

exports("RemoveCrypto", function(source, coinId, amount)
    local playerId = GetIdentifier(source)
    
    if not cryptoData.coins[coinId] then
        print("invalid coin", coinId)
        return false
    end
    
    if not playerId then
        print("no identifier")
        return false
    end
    
    MySQL.Async.execute(
        "UPDATE phone_crypto SET amount = amount - ? WHERE id = ? AND coin = ?",
        {amount, playerId, coinId}
    )
    
    TriggerClientEvent("phone:crypto:changeOwnedAmount", source, coinId, -amount)
    
    return true
end)

exports("AddCustomCoin", function(id, name, symbol, image, currentPrice, prices, change24h)
    assert(type(id) == "string", "id must be a string")
    assert(type(name) == "string", "name must be a string")
    assert(type(symbol) == "string", "symbol must be a string")
    assert(type(image) == "string", "image must be a string")
    assert(type(currentPrice) == "number", "currentPrice must be a number")
    assert(type(prices) == "table", "prices must be a table")
    assert(type(change24h) == "number", "change24h must be a number")
    
    local coinData = {
        id = id,
        name = name,
        symbol = symbol,
        image = image,
        current_price = currentPrice,
        prices = prices,
        change_24h = change24h
    }
    
    cryptoData.customCoins[id] = coinData
    cryptoData.coins[id] = coinData
    
    SetResourceKvp("lb-phone:crypto:coins", json.encode(cryptoData.coins))
    
    TriggerClientEvent("phone:crypto:updateCoins", -1, cryptoData.coins)
end)

exports("GetCoin", function(coinId)
    return cryptoData.coins[coinId]
end)