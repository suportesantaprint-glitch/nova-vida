-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Cooldown = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- BANNED:SERVICE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("banned:Service")
AddEventHandler("banned:Service",function()
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport then
		return false
	end

	local CurrentTimer = os.time()
	if Cooldown[Passport] and Cooldown[Passport] > CurrentTimer then
		return false
	end

	local Identity = vRP.Identity(Passport)
	if not Identity or Identity.Banned <= 0 then
		return false
	end

	Cooldown[Passport] = CurrentTimer + 60
	vRP.UpdateBanned(Passport)
end)