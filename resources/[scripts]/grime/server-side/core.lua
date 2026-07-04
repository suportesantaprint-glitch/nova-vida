-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRPC = Tunnel.getInterface("vRP")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Lil = {}
Tunnel.bindInterface("grime",Lil)
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Active = {}
local Attention = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- GRIME:PACKAGE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("grime:Package")
AddEventHandler("grime:Package",function()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] then
		if vRP.CheckWeight(Passport,Item) and not vRP.MaxItens(Passport,Item) then
			vRP.GenerateItem(Passport,Item,1)
		else
			TriggerClientEvent("Notify",source,"Mochila Sobrecarregada","Sua recompensa caiu no chão.","amarelo",5000)
			exports.inventory:Drops(Passport,source,Item,1)
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PAYMENT
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Payment(Selected)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] and vRP.TakeItem(Passport,Item) then
		Active[Passport] = true

		local Coords = vRP.GetEntityCoords(source)
		if not Selected or #(Coords - Locations[Selected]) > 2.5 then
			exports.discord:Embed("Hackers","**[PASSAPORTE]:** "..Passport.."\n**[FUNÇÃO]:** Payment do Grime",source)

			Attention[Passport] = (Attention[Passport] or 0) + 1
			if Attention[Passport] >= 5 then
				vRP.SetBanned(Passport,-1,"Hacker")
			end
		end

		local GainExperience = 3
		local Amount = math.random(175,275)
		local Experience,Level = vRP.GetExperience(Passport,"Grime")
		local Valuation = Amount + Amount * (0.05 * Level)

		if exports.inventory:Buffs("Dexterity",Passport) then
			Valuation = Valuation + (Valuation * 0.1)
		end

		for Permission,Multiplier in pairs({ Ouro = 0.1, Prata = 0.075, Bronze = 0.05 }) do
			if vRP.HasService(Passport,Permission) then
				Valuation = Valuation + (Valuation * Multiplier)
				GainExperience = GainExperience + 1
			end
		end

		vRP.GenerateItem(Passport,"dollar",Valuation,true)
		vRP.PutExperience(Passport,"Grime",GainExperience)
		vRP.BattlepassPoints(Passport,GainExperience)
		vRP.UpgradeStress(Passport,3)

		Active[Passport] = nil

		return true
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport,source)
	if Active[Passport] then
		Active[Passport] = nil
	end

	if Attention[Passport] then
		Attention[Passport] = nil
	end
end)