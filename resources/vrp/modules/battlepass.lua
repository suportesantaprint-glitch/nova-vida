-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Default = { Free = 0, Premium = 0, Points = 0, Active = false }
-----------------------------------------------------------------------------------------------------------------------------------------
-- BATTLEPASS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.Battlepass(Passport)
	local Consult = vRP.SimpleData(Passport,"Battlepass")
	if not Consult then
		vRP.Query("playerdata/SetData",{ Passport = Passport, Name = "Battlepass", Information = json.encode(Default) })

		return Default
	end

	return Consult
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- BATTLEPASSBUY
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.BattlepassBuy(Passport)
	local Consult = vRP.SimpleData(Passport,"Battlepass")
	if Consult then
		Consult.Active = true
		vRP.Query("playerdata/SetData",{ Passport = Passport, Name = "Battlepass", Information = json.encode(Consult) })
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- BATTLEPASSPAYMENT
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.BattlepassPayment(Passport,Mode,Amount)
	local Consult = vRP.SimpleData(Passport,"Battlepass")
	if not Consult or Consult.Points < Amount then
		return false
	end

	if Mode == "Free" then
		Consult.Free = Consult.Free + 1
	elseif Mode == "Premium" then
		Consult.Premium = Consult.Premium + 1
	end

	Consult.Points = Consult.Points - Amount

	vRP.Query("playerdata/SetData",{ Passport = Passport, Name = "Battlepass", Information = json.encode(Consult) })

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- BATTLEPASSPOINTS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.BattlepassPoints(Passport,Amount)
	local Consult = vRP.SimpleData(Passport,"Battlepass")
	if Consult then
		Consult.Points = Consult.Points + Amount
		vRP.Query("playerdata/SetData",{ Passport = Passport, Name = "Battlepass", Information = json.encode(Consult) })
		TriggerClientEvent("Notify",vRP.Source(Passport),"Passe de Batalha","Você recebeu "..Dotted(Amount).." pontos.","verde",5000)
	end
end