if Config.Framework ~= "standalone" then
    return
end

while not NetworkIsSessionStarted() do
    Wait(500)
end

FrameworkLoaded = true

local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
vSERVER = Tunnel.getInterface("lb-phone")