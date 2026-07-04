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
Tunnel.bindInterface("perimeter",Lil)
vKEYBOARD = Tunnel.getInterface("keyboard")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Perimeters = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- PERIMETERS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Perimeters()
	return Perimeters
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PERIMETER:NEW
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("perimeter:New")
AddEventHandler("perimeter:New",function()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		TriggerClientEvent("dynamic:Close",source)

		local Coords = vRP.GetEntityCoords(source)
		local Keyboard = vKEYBOARD.Secondary(source,"Nome","Distancia")
		if Keyboard then
			repeat
				Selected = GenerateString("DDLLDDLL")
			until Selected and not Perimeters[Selected]

			Perimeters[Selected] = {
				Name = Keyboard[1],
				Distance = parseInt(Keyboard[2],true),
				Coords = Coords
			}

			TriggerClientEvent("perimeter:Add",-1,Selected,Perimeters[Selected])
			exports.discord:Embed("Perimeter","**[PASSAPORTE]:** "..Passport.."\n**[NOME]:** "..Perimeters[Selected].Name.."\n**[COORDS]:** "..Coords)
			TriggerClientEvent("Notify",-1,"Informativo Policial","Informamos que o perímetro <b>"..Perimeters[Selected].Name.."</b> encontra-se fechado para circulação, pedimos a compreensão de todos e orientamos que busquem rotas alternativas, agradecemos pela colaboração.","policia",30000)
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PERIMETER:REMOVE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("perimeter:Remove")
AddEventHandler("perimeter:Remove",function(Selected)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and Perimeters[Selected] then
		TriggerClientEvent("Notify",-1,"Informativo Policial","Informamos que o perímetro <b>"..Perimeters[Selected].Name.."</b> encontra-se liberado para circulação, agradecemos pela colaboração e pedimos que todos sigam as orientações de segurança.","policia",30000)
		TriggerClientEvent("perimeter:Remove",-1,Selected)
		TriggerClientEvent("dynamic:Close",source)
		Perimeters[Selected] = nil
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Connect",function(Passport,source)
	TriggerClientEvent("perimeter:List",source,Perimeters)
end)