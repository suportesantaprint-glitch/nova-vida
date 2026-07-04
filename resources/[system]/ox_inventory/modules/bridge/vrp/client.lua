if not lib then return end

local IDGenerator = {}
function IDGenerator:construct()
    self.max = 0
    self.ids = {}
end
function IDGenerator:gen()
    if #self.ids > 0 then
        return table.remove(self.ids)
    else
        local r = self.max
        self.max = self.max + 1
        return r
    end
end
function IDGenerator:free(id)
    table.insert(self.ids, id)
end

local function newIDGenerator()
    local r = setmetatable({}, { __index = IDGenerator })
    r:construct()
    return r
end

local function wait(self)
    local rets = Citizen.Await(self.p)
    if not rets and self.r then
        rets = self.r
    end
    return table.unpack(rets or {}, 1, rets and #rets or 0)
end

local function areturn(self, ...)
    self.r = { ... }
    self.p:resolve(self.r)
end

local function async()
    return setmetatable({ wait = wait, p = promise.new() }, { __call = areturn })
end

local function proxy_resolve(itable, key)
    local mtable = getmetatable(itable)
    local iname = mtable.name
    local ids = mtable.ids
    local callbacks = mtable.callbacks
    local identifier = mtable.identifier

    local fname = key
    local no_wait = false
    if string.sub(key, 1, 1) == "_" then
        fname = string.sub(key, 2)
        no_wait = true
    end

    local fcall = function(...)
        local rid, r
        if no_wait then
            rid = -1
        else
            r = async()
            rid = ids:gen()
            callbacks[rid] = r
        end

        local Message = { ... }
        TriggerEvent(iname .. ":proxy", fname, Message, identifier, rid)

        if not no_wait then
            return r:wait()
        end
    end

    itable[key] = fcall
    return fcall
end

local function getInterface(name, identifier)
    if not identifier then
        identifier = GetCurrentResourceName()
    end

    local callbacks = {}
    local ids = newIDGenerator()
    local r = setmetatable({}, { __index = proxy_resolve, name = name, ids = ids, callbacks = callbacks, identifier = identifier })

    AddEventHandler(name .. ":" .. identifier .. ":proxy_res", function(rid, rets)
        local callback = callbacks[rid]
        if callback then
            ids:free(rid)
            callbacks[rid] = nil
            callback(table.unpack(rets or {}, 1, rets and #rets or 0))
        end
    end)

    return r
end

local vRP = getInterface("vRP")

-- Sync player groups from local player state bags
CreateThread(function()
    while not LocalPlayer.state.Passport do
        Wait(500)
    end
    
    local groups = vRP.Groups()
    if groups then
        for groupName in pairs(groups) do
            local stateVal = LocalPlayer.state[groupName]
            if stateVal then
                PlayerData.groups[groupName] = stateVal
            end
            
            AddStateBagChangeHandler(groupName, ('player:%s'):format(GetPlayerServerId(PlayerId())), function(bagName, key, value)
                PlayerData.groups[key] = value
                OnPlayerData('groups')
            end)
        end
        OnPlayerData('groups')
    end
end)
