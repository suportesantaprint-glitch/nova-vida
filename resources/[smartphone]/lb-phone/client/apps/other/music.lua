local function getPlaylistData()
    local serverPlaylists = AwaitCallback("music:getPlaylists")
    local playlists = {}
    local processedIds = {}
    
    for i = 1, #serverPlaylists do
        local playlist = serverPlaylists[i]
        
        if not processedIds[playlist.id] then
            processedIds[playlist.id] = true
            
            table.insert(playlists, {
                Id = playlist.id,
                Title = playlist.name,
                Cover = playlist.cover,
                IsOwner = playlist.phone_number == currentPhone,
                Songs = {}
            })
        end
        
        if playlist.song_id then
            local currentPlaylist = playlists[#playlists]
            table.insert(currentPlaylist.Songs, playlist.song_id)
        end
    end
    
    return playlists
end

RegisterNUICallback("Music", function(data, callback)
    local action = data.action
    debugprint("Music:" .. (action or ""))
    
    if action == "getConfig" then
        callback(Music)
    elseif action == "createPlaylist" then
        TriggerCallback("music:createPlaylist", callback, data.name)
    elseif action == "editPlaylist" then
        TriggerCallback("music:editPlaylist", callback, data.id, data.title, data.cover)
    elseif action == "getPlaylists" then
        callback(getPlaylistData())
    elseif action == "deletePlaylist" then
        TriggerCallback("music:deletePlaylist", callback, data.id)
    elseif action == "savePlaylist" then
        TriggerCallback("music:savePlaylist", callback, data.id)
    elseif action == "addSong" then
        TriggerCallback("music:addSong", callback, data.id, data.song)
    elseif action == "removeSong" then
        TriggerCallback("music:removeSong", callback, data.id, data.song)
    end
end)