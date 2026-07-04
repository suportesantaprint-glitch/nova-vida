-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Posts = {}
local Active = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- ADD
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Add(Coords)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] then
		Active[Passport] = true

		local Route = GetPlayerRoutingBucket(source)
		local Keyboard = vKEYBOARD.Secondary(source,"Mensagem","Distância (3 a 15)")
		if Keyboard and parseInt(Keyboard[2]) >= 3 and parseInt(Keyboard[2]) <= 15 and vRP.TakeItem(Passport,"postit",1,true) then
			Posts[Route] = Posts[Route] or {}

			repeat
				Selected = GenerateString("DDLLDDLL")
			until Selected and not Posts[Route][Selected]

			Posts[Route][Selected] = {
				Coords = Coords,
				Author = "Post-it",
				Message = string.sub(Keyboard[1],1,100),
				Distance = parseInt(Keyboard[2]),
				Passport = Passport
			}

			TriggerClientEvent("chat:postit_add",-1,Route,Selected,Posts[Route][Selected])
		end

		Active[Passport] = nil
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DELETE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Delete(Route,Selected)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] and Posts[Route] and Posts[Route][Selected] then
		Active[Passport] = true

		if vRP.HasGroup(Passport,"Admin") then
			TriggerClientEvent("Notify",source,"Sucesso","Post-It do passaporte <b>"..Posts[Route][Selected].Passport.."</b> removido.","verde",10000)
			TriggerClientEvent("chat:postit_remove",-1,Route,Selected)
			Posts[Route][Selected] = nil
		elseif Posts[Route][Selected].Passport == Passport then
			TriggerClientEvent("chat:postit_remove",-1,Route,Selected)
			Posts[Route][Selected] = nil
		end

		Active[Passport] = nil
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- POSTIT
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Postit",function(Passport,Coords,Reason,Seconds)
	local Selected
	local Route = 0

	Posts[Route] = Posts[Route] or {}

	repeat
		Selected = GenerateString("DDLLDDLL")
	until Selected and not Posts[Route][Selected]

	Posts[Route][Selected] = {
		Distance = 20,
		Coords = Coords,
		Message = Reason,
		Passport = Passport,
		Author = "Passporte: "..Passport
	}

	TriggerClientEvent("chat:postit_add",-1,Route,Selected,Posts[Route][Selected])

	SetTimeout(Seconds * 1000,function()
		TriggerClientEvent("chat:postit_remove",-1,Route,Selected)
	end)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport)
	if Active[Passport] then
		Active[Passport] = nil
	end
end)