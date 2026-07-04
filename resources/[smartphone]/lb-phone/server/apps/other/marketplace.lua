local POSTS_PER_PAGE = 15

local function getMarketplacePosts(page, filters)
    page = page or 0
    
    local queryParams = {}
    local whereConditions = {}
    
    if filters and filters.search then
        table.insert(whereConditions, "(title LIKE ? OR description LIKE ?)")
        local searchPattern = "%" .. filters.search .. "%"
        table.insert(queryParams, searchPattern)
        table.insert(queryParams, searchPattern)
        
        if not filters.from then
            table.insert(whereConditions, "OR phone_number LIKE ?")
            table.insert(queryParams, searchPattern)
        end
    end
    
    if filters and filters.from then
        local condition = ""
        if #whereConditions > 0 then
            condition = "AND "
        end
        condition = condition .. "phone_number = ?"
        table.insert(whereConditions, condition)
        table.insert(queryParams, filters.from)
    end
    
    local baseQuery = [[
        SELECT
            id,
            phone_number AS `number`,
            title,
            description,
            attachments,
            price,
            `timestamp`
        FROM
            phone_marketplace_posts
        {WHERE}
        ORDER BY
            `timestamp` DESC
        LIMIT ?, ?
    ]]
    
    local whereClause = ""
    if #whereConditions > 0 then
        whereClause = "WHERE " .. table.concat(whereConditions, " ")
    end
    
    local finalQuery = baseQuery:gsub("{WHERE}", whereClause)
    
    local offset = (page or 0) * POSTS_PER_PAGE
    table.insert(queryParams, offset)
    table.insert(queryParams, POSTS_PER_PAGE)
    
    return MySQL.query.await(finalQuery, queryParams)
end

BaseCallback("marketplace:getPosts", function(source, phoneNumber, data)
    return getMarketplacePosts(data.page, {
        from = data.from,
        search = data.query
    })
end)

BaseCallback("marketplace:createPost", function(source, phoneNumber, postData)
    local title = postData.title
    local description = postData.description
    local attachments = postData.attachments
    local price = postData.price
    
    if not (title and description and attachments and price) or price < 0 then
        return false
    end
    
    if ContainsBlacklistedWord(source, "MarketPlace", title) then
        return false
    end
    
    if ContainsBlacklistedWord(source, "MarketPlace", description) then
        return false
    end
    
    local postId = MySQL.insert.await(
        "INSERT INTO phone_marketplace_posts (phone_number, title, description, attachments, price) VALUES (?, ?, ?, ?, ?)",
        {
            phoneNumber,
            title,
            description,
            json.encode(attachments),
            price
        }
    )
    
    if not postId then
        return false
    end
    
    postData.number = phoneNumber
    postData.id = postId
    
    TriggerClientEvent("phone:marketplace:newPost", -1, postData)
    
    TriggerEvent("lb-phone:marketplace:newPost", postData)
    
    Log("Marketplace", source, "info", 
        L("BACKEND.LOGS.MARKETPLACE_NEW_TITLE"),
        L("BACKEND.LOGS.MARKETPLACE_NEW_DESCRIPTION", {
            seller = FormatNumber(phoneNumber),
            title = title,
            price = price,
            description = description,
            attachments = json.encode(attachments),
            id = postId
        })
    )
    
    return postId
end)

BaseCallback("marketplace:deletePost", function(source, phoneNumber, postId)
    local isAdmin = IsAdmin(source)
    local queryParams = {postId}
    local deleteQuery = "DELETE FROM phone_marketplace_posts WHERE id = ?"
    
    if not isAdmin then
        deleteQuery = deleteQuery .. " AND phone_number = ?"
        table.insert(queryParams, phoneNumber)
    end
    
    local affectedRows = MySQL.update.await(deleteQuery, queryParams)
    
    if affectedRows > 0 then
        Log("Marketplace", source, "error", 
            L("BACKEND.LOGS.MARKETPLACE_DELETED"),
            ("**ID**: %s"):format(postId)
        )
        return true
    end
    
    return false
end)