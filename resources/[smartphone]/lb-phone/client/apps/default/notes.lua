RegisterNUICallback("Notes", function(data, callback)
    if not currentPhone then
        return
    end
    
    local action = data.action
    debugprint("Notes:" .. (action or ""))
    
    if data.data then
        data = data.data
    end
    
    if action == "create" then
        TriggerCallback("notes:createNote", callback, data.title, data.content)
    elseif action == "save" then
        TriggerCallback("notes:saveNote", callback, data.id, data.title, data.content)
    elseif action == "fetch" then
        TriggerCallback("notes:getNotes", callback)
    elseif action == "remove" then
        TriggerCallback("notes:removeNote", callback, data.id)
    end
end)