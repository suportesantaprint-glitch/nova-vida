if Config.Crypto and Config.Crypto.Enabled then
    local cryptoData = {}
    local isBusy = false
    
    local function findCoinById(coinId)
        for index, coin in ipairs(cryptoData) do
            if coin.id == coinId then
                return index, coin
            end
        end
        return false
    end
    
    local function updateQBitData()
        if not (Config.Crypto and Config.Crypto.QBit and Config.Framework == "qb") then
            return
        end
        
        local index = findCoinById("qbit")
        if not index then
            index = #cryptoData + 1
        end
        
        local qbitData = GetQBit()
        local priceHistory = {}
        
        for i = 1, #qbitData.History do
            table.insert(priceHistory, qbitData.History[i].PreviousWorth)
            table.insert(priceHistory, qbitData.History[i].NewWorth)
        end
        
        if #qbitData.History == 0 then
            for i = 1, 10 do
                priceHistory[i] = qbitData.Worth + math.random(-10, 10)
            end
        end
        
        local change24h = 0
        if #qbitData.History > 0 then
            local lastEntry = qbitData.History[#qbitData.History]
            local firstEntry = qbitData.History[1]
            change24h = lastEntry.NewWorth - firstEntry.PreviousWorth
        end
        
        cryptoData[index] = {
            change_24h = change24h,
            current_price = qbitData.Worth,
            id = "qbit",
            image = "https://avatars.githubusercontent.com/u/81791099?s=200&v=4",
            name = "QBit",
            prices = priceHistory,
            symbol = "qbit",
            owned = qbitData.Portfolio
        }
    end
    
    local function buyCrypto(coinId, amount)
        local result
        
        if coinId == "qbit" and BuyQBit then
            result = BuyQBit(amount)
        else
            result = AwaitCallback("crypto:buy", coinId, amount)
        end
        
        isBusy = false
        
        if not result.success then
            return result
        end
        
        local index, coinData = findCoinById(coinId)
        if not coinData then
            return result
        end
        
        coinData.owned = (coinData.owned or 0) + (amount / coinData.current_price)
        coinData.invested = (coinData.invested or 0) + amount
        
        return result
    end
    
    local function sellCrypto(coinId, amount)
        local result
        
        if coinId == "qbit" and SellQBit then
            result = SellQBit(amount)
        else
            result = AwaitCallback("crypto:sell", coinId, amount)
        end
        
        isBusy = false
        
        if not result.success then
            return result
        end
        
        local index, coinData = findCoinById(coinId)
        if not coinData or not coinData.invested or not coinData.owned then
            return result
        end
        
        coinData.invested = coinData.invested - (amount * coinData.current_price)
        coinData.owned = coinData.owned - amount
        
        return result
    end
    
    local function transferCrypto(coinId, amount, targetNumber)
        local result
        
        if coinId == "qbit" and TransferQBit then
            result = TransferQBit(amount)
        else
            result = AwaitCallback("crypto:transfer", coinId, amount, targetNumber)
        end
        
        isBusy = false
        
        if not result.success then
            return result
        end
        
        local index, coinData = findCoinById(coinId)
        if not coinData or not coinData.invested or not coinData.owned then
            return result
        end
        
        coinData.invested = coinData.invested - (amount * coinData.current_price)
        coinData.owned = coinData.owned - amount
        
        return result
    end
    
    RegisterNUICallback("Crypto", function(data, callback)
        local action = data.action
        debugprint("Crypto:" .. (action or ""))
        
        if action == "buy" or action == "sell" or action == "transfer" then
            if isBusy then
                return callback({success = false, msg = "BUSY"})
            end
            isBusy = true
        end
        
        if action == "buy" then
            callback(buyCrypto(data.coin, data.amount))
        elseif action == "sell" then
            callback(sellCrypto(data.coin, data.amount))
        elseif action == "transfer" then
            callback(transferCrypto(data.coin, data.amount, data.number))
        elseif action == "get" then
            updateQBitData()
            callback(cryptoData)
        end
    end)
    
    CreateThread(function()
        while not FrameworkLoaded do
            Wait(0)
        end
        
        local serverData = AwaitCallback("crypto:get")
        cryptoData = {}
        
        for _, coin in pairs(serverData) do
            table.insert(cryptoData, coin)
        end
        
        debugprint("fetched coins")
    end)
    
    RegisterNetEvent("phone:crypto:updateCoins", function(updatedCoins)
        for i = 1, #cryptoData do
            local coin = cryptoData[i]
            local updatedCoin = updatedCoins[coin.id]
            
            if updatedCoin then
                coin.current_price = updatedCoin.current_price
                coin.change_24h = updatedCoin.change_24h
                coin.prices = updatedCoin.prices
            end
        end
        
        for coinId, coinData in pairs(updatedCoins) do
            if not findCoinById(coinId) then
                table.insert(cryptoData, coinData)
            end
        end
        
        debugprint("updated crypto cache")
        SendReactMessage("crypto:updateCoins", cryptoData)
    end)
    
    RegisterNetEvent("phone:crypto:changeOwnedAmount", function(coinId, changeAmount)
        local index, coinData = findCoinById(coinId)
        if not coinData then
            return
        end
        
        coinData.owned = (coinData.owned or 0) + changeAmount
        
        debugprint("updated crypto cache", coinId, changeAmount, coinData.owned)
        SendReactMessage("crypto:updateCoins", cryptoData)
    end)
    
    exports("GetCoinValue", function(coinId)
        local index, coinData = findCoinById(coinId)
        return coinData and coinData.current_price
    end)
    
    exports("GetCryptoWallet", function()
        return cryptoData
    end)
    
    exports("GetOwnedCoin", function(coinId)
        local index, coinData = findCoinById(coinId)
        return coinData
    end)
end