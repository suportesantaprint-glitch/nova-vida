if Config.Framework ~= "standalone" then
    return
end

---@param itemName string
---@return boolean
function HasItem(itemName)
    if not LocalPlayer["state"]["Active"] or IsPauseMenuActive() or LocalPlayer["state"]["Buttons"] or LocalPlayer["state"]["Commands"] or LocalPlayer["state"]["Handcuff"] or LocalPlayer["state"]["Cancel"] or IsPedReloading(Ped) then
        return false
    end

    return vSERVER.CheckPhone()
end