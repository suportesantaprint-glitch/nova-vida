-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Radio = {
	["911"] = "Policia",
	["912"] = "Policia",
	["913"] = "Policia",
	["914"] = "Policia",
	["915"] = "Policia",
	["916"] = "Policia",
	["917"] = "Policia",
	["918"] = "Policia",
	["919"] = "Policia",
	["920"] = "Policia",
	["112"] = "Paramedico",
	["113"] = "Paramedico",
	["114"] = "Paramedico"
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- FREQUENCY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Frequency(Number)
	local source = source
	local Number = tostring(Number)
	local Passport = vRP.Passport(source)
	if Passport and Radio[Number] and not vRP.HasService(Passport,Radio[Number]) then
		TriggerClientEvent("Notify",source,"Atenção","Necessário permissão para efetuar conexão.","amarelo",5000)

		return false
	end

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADINITSYSTEM
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	local Consult = vRP.GetSrvData("Radio",true)
	if Consult then
		for Number,Permission in pairs(Consult) do
			Radio[Number] = Permission
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- RADIOEXIST
-----------------------------------------------------------------------------------------------------------------------------------------
exports("RadioExist",function(Number)
	return Radio[Number]
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- RADIOADD
-----------------------------------------------------------------------------------------------------------------------------------------
exports("RadioAdd",function(Number,Permission)
	local Consult = vRP.GetSrvData("Radio",true)
	if Consult then
		Radio[Number] = Permission
		Consult[Number] = Permission

		vRP.SetSrvData("Radio",Consult,true)
	end
end)