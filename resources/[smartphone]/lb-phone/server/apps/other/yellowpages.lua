local POSTS_PER_PAGE = 10

BaseCallback("yellowPages:getPosts", function(source, phoneNumber, page, filters)
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
            attachment,
            price,
            `timestamp`
        FROM
            phone_yellow_pages_posts
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
end)

BaseCallback("yellowPages:createPost", function(source, phoneNumber, postData)
    if not (postData and postData.title and postData.description) then
        return false
    end
    
    if ContainsBlacklistedWord(source, "Pages", postData.title) then
        return false
    end
    
    if ContainsBlacklistedWord(source, "Pages", postData.description) then
        return false
    end
    
    local postId = MySQL.insert.await(
        "INSERT INTO phone_yellow_pages_posts (phone_number, title, description, attachment, price) VALUES (@number, @title, @description, @attachment, @price)",
        {
            ["@number"] = phoneNumber,
            ["@title"] = postData.title,
            ["@description"] = postData.description,
            ["@attachment"] = postData.attachment,
            ["@price"] = tonumber(postData.price)
        }
    )
    
    if not postId then
        return false
    end
    
    postData.id = postId
    postData.number = phoneNumber
    
    TriggerClientEvent("phone:yellowPages:newPost", -1, postData)
    
    TriggerEvent("lb-phone:pages:newPost", postData)
    
    Log("YellowPages", source, "info", 
        L("BACKEND.LOGS.YELLOWPAGES_NEW_TITLE"),
        L("BACKEND.LOGS.YELLOWPAGES_NEW_DESCRIPTION", {
            title = postData.title,
            description = postData.description,
            attachment = postData.attachment or "",
            id = postData.id
        })
    )
    
    return postId
end)

BaseCallback("yellowPages:deletePost", function(source, phoneNumber, postId)
    local isAdmin = IsAdmin(source)
    
    local deleteQuery = "DELETE FROM phone_yellow_pages_posts WHERE id = @id"
    
    if not isAdmin then
        deleteQuery = deleteQuery .. " AND phone_number = @number"
    end
    
    local affectedRows = MySQL.update.await(deleteQuery, {
        ["@id"] = postId,
        ["@number"] = phoneNumber
    })
    
    local success = affectedRows > 0
    
    if success then
        Log("YellowPages", source, "error", 
            L("BACKEND.LOGS.YELLOWPAGES_DELETED"),
            ("**ID**: %s"):format(postId)
        )
    end
    
    return true
end)