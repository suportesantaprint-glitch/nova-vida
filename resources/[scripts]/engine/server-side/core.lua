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
Tunnel.bindInterface("engine",Lil)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PAYMENTFUEL
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.RechargeFuel(Price,Permission,Fuel)
	local Check = false
	local source = source
	local Fuel = parseInt(Fuel)
	local Passport = vRP.Passport(source)
	if not Passport or not Price or Fuel <= 0 then
		return false
	end

	if Permission then
		local Consult = exports.oxmysql:single_async("SELECT Name,Stock FROM fuelstations_creative WHERE Permission = ?",{ Permission })
		if Consult and Consult.Stock < Fuel then
			TriggerClientEvent("Notify",source,Consult.Name,"Combustível insuficiente.","amarelo",5000)
			return false
		end

		Check = Consult and true or false
	end

	if vRP.PaymentFull(Passport,Price) then
		if Check and Permission then
			exports.fuelstations:UpdateStock(Permission,Fuel,"-",Price)
			vRP.PermissionsUpdate(Permission,"Bank","+",Price)
		end

		return true
	end

	TriggerClientEvent("Notify",source,"Aviso","Dinheiro insuficiente.","amarelo",5000)

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- ENGINE:SYNCFUEL
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("engine:SyncFuel")
AddEventHandler("engine:SyncFuel",function(Network,Fuel)
	local Vehicle = NetworkGetEntityFromNetworkId(Network)
	if DoesEntityExist(Vehicle) then
		Entity(Vehicle).state:set("Fuel",Fuel,true)
	end
end)