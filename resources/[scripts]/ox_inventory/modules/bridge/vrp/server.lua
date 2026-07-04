if not lib then return end

local Proxy = {}
local callbacks = {}
local next_rid = 0

local function proxy_resolve(itable, key)
    local mtable = getmetatable(itable)
    local iname = mtable.name
    local identifier = mtable.identifier

    local fname = key
    local no_wait = false
    if string.sub(key, 1, 1) == "_" then
        fname = string.sub(key, 2)
        no_wait = true
    end

    local fcall = function(...)
        local rid
        local p

        if no_wait then
            rid = -1
        else
            p = promise.new()
            rid = next_rid
            next_rid = next_rid + 1
            callbacks[rid] = p
        end

        local Message = {...}
        TriggerEvent(iname..":proxy", fname, Message, identifier, rid)
    
        if not no_wait then
            local rets = Citizen.Await(p)
            return table.unpack(rets)
        end
    end

    itable[key] = fcall
    return fcall
end

function Proxy.getInterface(name, identifier)
    if not identifier then
        identifier = GetCurrentResourceName()
    end

    local r = setmetatable({}, { __index = proxy_resolve, name = name, identifier = identifier })

    AddEventHandler(name..":"..identifier..":proxy_res", function(rid, rets)
        local p = callbacks[rid]
        if p then
            callbacks[rid] = nil
            p:resolve(rets)
        end
    end)

    return r
end

local vRP = Proxy.getInterface("vRP")
local Inventory = require 'modules.inventory.server'

-- Event handler for player character selection
AddEventHandler("CharacterChosen", function(Passport, source, Creation)
    local source = tonumber(source)
    local Passport = tonumber(Passport)

    CreateThread(function()
        local Identity = vRP.Identity(Passport)
        if not Identity then return end

        local groups = vRP.UserGroups(Passport) or {}

        local player = {
            source = source,
            identifier = Passport,
            name = Identity.Name .. " " .. Identity.Lastname,
            groups = groups,
            sex = Identity.Skin == 'mp_m_freemode_01' and 'm' or 'f',
            dateofbirth = Identity.Age or '1990-01-01',
        }

        server.setPlayerInventory(player)
    end)
end)

-- Startup loading routine for already online players (e.g. resource restarts)
SetTimeout(500, function()
    local players = vRP.Players()
    if players then
        for Passport, source in pairs(players) do
            local passportNum = tonumber(Passport)
            local sourceNum = tonumber(source)
            if passportNum and sourceNum then
                local Identity = vRP.Identity(passportNum)
                if Identity then
                    local groups = vRP.UserGroups(passportNum) or {}
                    local player = {
                        source = sourceNum,
                        identifier = passportNum,
                        name = Identity.Name .. " " .. Identity.Lastname,
                        groups = groups,
                        sex = Identity.Skin == 'mp_m_freemode_01' and 'm' or 'f',
                        dateofbirth = Identity.Age or '1990-01-01',
                    }
                    server.setPlayerInventory(player)
                end
            end
        end
    end
end)

---@diagnostic disable-next-line: duplicate-set-field
function server.hasGroup(inv, group)
    local Passport = tonumber(inv.owner)
    if not Passport then return end

    if type(group) == 'table' then
        for name, requiredRank in pairs(group) do
            local groupRank = vRP.HasGroup(Passport, name) or vRP.HasPermission(Passport, name)
            if groupRank then
                if type(requiredRank) == 'table' then
                    if lib.table.contains(requiredRank, groupRank) then
                        return name, groupRank
                    end
                else
                    if type(requiredRank) == 'number' then
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
        local groupRank = vRP.HasGroup(Passport, group) or vRP.HasPermission(Passport, group)
        if groupRank then
            return group, groupRank
        end
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function server.buyLicense(inv, license)
    local Passport = tonumber(inv.owner)
    if not Passport then return false end

    if vRP.HasPermission(Passport, license.name) or vRP.HasGroup(Passport, license.name) then
        return false, 'already_have'
    elseif Inventory.GetItemCount(inv, 'money') < license.price then
        return false, 'can_not_afford'
    end

    Inventory.RemoveItem(inv, 'money', license.price)
    vRP.SetPermission(Passport, license.name, 1)

    return true, 'have_purchased'
end

---@diagnostic disable-next-line: duplicate-set-field
function server.hasLicense(inv, licenseName)
    local Passport = tonumber(inv.owner)
    if not Passport then return false end
    return vRP.HasPermission(Passport, licenseName) or vRP.HasGroup(Passport, licenseName)
end

---@diagnostic disable-next-line: duplicate-set-field
function server.isPlayerBoss(playerId, group, grade)
    local Passport = vRP.Passport(playerId)
    if not Passport then return false end
    local groupRank = vRP.HasGroup(Passport, group) or vRP.HasPermission(Passport, group)
    return groupRank == 1
end

---@diagnostic disable-next-line: duplicate-set-field
function server.getOwnedVehicleId(entityId)
    local plate = GetVehicleNumberPlateText(entityId)
    if plate then
        return server.trimplate and plate:gsub('%s+', '') or plate
    end
end

-- Server status upgrade events to hook NUI status updates to vRP datatables
RegisterNetEvent('vrp:upgradeHunger', function(amount)
    local source = source
    local Passport = vRP.Passport(source)
    if Passport then
        vRP.UpgradeHunger(Passport, amount)
    end
end)

RegisterNetEvent('vrp:upgradeThirst', function(amount)
    local source = source
    local Passport = vRP.Passport(source)
    if Passport then
        vRP.UpgradeThirst(Passport, amount)
    end
end)
