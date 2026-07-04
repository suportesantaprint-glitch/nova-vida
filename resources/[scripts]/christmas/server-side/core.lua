-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- GLOBALSTATE
-----------------------------------------------------------------------------------------------------------------------------------------
GlobalState.Christbox = 0
GlobalState.Christmas = false
-----------------------------------------------------------------------------------------------------------------------------------------
-- GLOBALSTATE
-----------------------------------------------------------------------------------------------------------------------------------------
for Index in pairs(Locations) do
	GlobalState["Christmas:"..Index] = false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHRISTMAS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("christmas",function(source)
	local Passport = vRP.Passport(source)
	if not Passport or not vRP.HasGroup(Passport,"Admin") then
		return false
	end

	local Starting = not GlobalState.Christmas
	GlobalState.Christbox = #Locations
	GlobalState.Christmas = Starting

	if Starting then
		GlobalState.Christbox = #Locations

		for Index in pairs(Locations) do
			local Multiplier = math.random(1,2)
			if vRP.MountContainer(Passport,"Christmas:"..Index,Loots,Multiplier) then
				GlobalState["Christmas:"..Index] = true
			end
		end

		TriggerClientEvent("Notify",-1,"Feliz Natal!","Começou a caça aos presentes.","default",30000)
	else
		GlobalState.Christbox = 0
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ADDSTATEBAGCHANGEHANDLER
-----------------------------------------------------------------------------------------------------------------------------------------
AddStateBagChangeHandler("Christbox",nil,function(_,_,Value)
	if Value <= 0 then
		for Index in pairs(Locations) do
			GlobalState["Christmas:"..Index] = false
			vRP.RemSrvData("Christmas:"..Index,true)
		end

		TriggerClientEvent("Notify",-1,"Feliz Natal!","Terminou a caça aos presentes.","default",30000)
		GlobalState.Christmas = false
	end
end)