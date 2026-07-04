-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Lil = {}
Tunnel.bindInterface("megazord",Lil)
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
GlobalState["Resource"] = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- WARNING
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Warning(Message,Banned)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and Message and not vRP.HasService(Passport,PermBypass) then
		exports.discord:Embed("Hackers","**[SOURCE]:** "..source.."\n**[PASSAPORTE]:** "..Passport.."\n**[MOTIVO]:** "..Message.."\n**[DATA & HORA]:** "..os.date("%d/%m/%Y").." às "..os.date("%H:%M"),source)

		if Banned then
			vRP.SetBanned(Passport,-1,"Permanente",Message)
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADRESOURCES
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	local ResourceList = {}
	for Number = 0,(GetNumResources() - 1) do
		ResourceList[GetResourceByFindIndex(Number)] = true
	end

	GlobalState["Resource"] = ResourceList
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- EXPLOSIONEVENT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("explosionEvent",function(source,Data)
	local source = source
	local ExplosionType = tonumber(Data["explosionType"])
	if Explodes[ExplosionType] then
		CancelEvent()

		local Passport = vRP.Passport(source)
		if Passport and not vRP.HasService(Passport,PermBypass) then
			exports.discord:Embed("Hackers","**[SOURCE]:** "..source.."\n**[PASSAPORTE]:** "..Passport.."\n**[MOTIVO]:** "..Explodes[ExplosionType].."\n**[DATA & HORA]:** "..os.date("%d/%m/%Y").." às "..os.date("%H:%M"),source)
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ENTITYCREATING
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("entityCreating",function(Entity)
	if DoesEntityExist(Entity) then
		if BannedModels[GetEntityModel(Entity)] or NetworkGetEntityOwner(Entity) == nil then
			CancelEvent()

			return
		end

		if GetEntityType(Entity) == 2 then
			SetVehicleDoorsLocked(Entity,2)
		end
	else
		CancelEvent()
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- HACKEREVENTS
-----------------------------------------------------------------------------------------------------------------------------------------
for Number = 1,#HackerEvents do
	RegisterServerEvent(HackerEvents[Number])
	AddEventHandler(HackerEvents[Number],function()
		local source = source
		local Passport = vRP.Passport(source)
		if Passport and not vRP.HasService(Passport,PermBypass) then
			exports.discord:Embed("Hackers","**[SOURCE]:** "..source.."\n**[PASSAPORTE]:** "..Passport.."\n**[MOTIVO]:** Hacker Events\n**[DATA & HORA]:** "..os.date("%d/%m/%Y").." às "..os.date("%H:%M"),source)
			vRP.SetBanned(Passport,-1,"Permanente","Hacker")
		end
	end)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PTFXEVENT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("ptFxEvent",function(source,Data)
	if Particles[Data.effectHash] or Assets[Data.assetHash] then
		CancelEvent()

		local source = source
		local Passport = vRP.Passport(source)
		if Passport and not vRP.HasService(Passport,PermBypass) then
			exports.discord:Embed("Hackers","**[SOURCE]:** "..source.."\n**[PASSAPORTE]:** "..Passport.."\n**[MOTIVO]:** Particles/Assets Block\n**[DATA & HORA]:** "..os.date("%d/%m/%Y").." às "..os.date("%H:%M"),source)
			vRP.SetBanned(Passport,-1,"Permanente","Hacker")
		end
	end
end)