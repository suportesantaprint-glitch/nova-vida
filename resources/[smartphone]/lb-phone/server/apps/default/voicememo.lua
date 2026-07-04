BaseCallback("voiceMemo:saveRecording", function(source, phoneNumber, recordingData)
    if not recordingData.src or not recordingData.duration then
        debugprint("VoiceMemo: no src/duration, not saving")
        return
    end
    
    local title = recordingData.title or "Unknown"
    local fileUrl = recordingData.src
    local duration = recordingData.duration
    
    return MySQL.insert.await(
        "INSERT INTO phone_voice_memos_recordings (phone_number, file_name, file_url, file_length) VALUES (?, ?, ?, ?)",
        {phoneNumber, title, fileUrl, duration}
    )
end)

BaseCallback("voiceMemo:getMemos", function(source, phoneNumber)
    return MySQL.query.await(
        "SELECT id, file_name AS `title`, file_url AS `src`, file_length AS `duration`, created_at AS `timestamp` FROM phone_voice_memos_recordings WHERE phone_number = ? ORDER BY created_at DESC",
        {phoneNumber}
    )
end, {})

BaseCallback("voiceMemo:deleteMemo", function(source, phoneNumber, memoId)
    local affectedRows = MySQL.update.await(
        "DELETE FROM phone_voice_memos_recordings WHERE id = ? AND phone_number = ?",
        {memoId, phoneNumber}
    )
    return affectedRows > 0
end)

BaseCallback("renameMemo", function(source, phoneNumber, memoId, newName)
    local affectedRows = MySQL.update.await(
        "UPDATE phone_voice_memos_recordings SET file_name = ? WHERE id = ? AND phone_number = ?",
        {newName, memoId, phoneNumber}
    )
    return affectedRows > 0
end)