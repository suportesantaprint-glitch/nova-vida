if not lib then return end

local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
local vRP = Proxy.getInterface("vRP")

local Weapon = require 'modules.weapon.client'

---@diagnostic disable-next-line: duplicate-set-field
function client.hasGroup(group)
    if type(group) == 'table' then
        for name, requiredRank in pairs(group) do
            local groupRank = LocalPlayer.state[name]
            if groupRank then
                if type(requiredRank) == 'table' then
                    if lib.table.contains(requiredRank, groupRank) then
                        return name, groupRank
                    end
                else
                    if type(requiredRank) == 'number' then
                        -- In vRP, lower rank level means HIGHER authority (1 is boss)
                        if groupRank <= requiredRank then
                            return name, groupRank
                        end
                    else
                        return name, groupRank
                    end
                end
            end
        end
    else
        local groupRank = LocalPlayer.state[group]
        if groupRank then
            return group, groupRank
        end
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function client.setPlayerStatus(values)
    for name, value in pairs(values) do
        -- Standardize value if it's based on the 1000000 scale
        if value > 100 or value < -100 then
            if (name == 'hunger' or name == 'thirst') then
                value = -value
            end
            value = value * 0.0001
        end

        if name == 'hunger' then
            TriggerServerEvent('vrp:upgradeHunger', math.floor(value))
        elseif name == 'thirst' then
            TriggerServerEvent('vrp:upgradeThirst', math.floor(value))
        end
    end
end

-- Handcuff state handler using vRP's player StateBag
AddStateBagChangeHandler('Handcuff', ('player:%s'):format(cache.serverId), function(bagName, key, value, reserved, replicated)
    PlayerData.cuffed = value
    client.player:setr('invBusy', value)

    if value then
        Weapon.Disarm()
    end
end)
