-----------------------------------------------------------------------------------------------------------------------------------------
-- CLOSESTVEHICLE
-----------------------------------------------------------------------------------------------------------------------------------------
function tvRP.ClosestVehicle(Radius)
	local Model = false
	local Selected = false
	local Ped = PlayerPedId()
	local Radius = Radius + 0.0001
	local Coords = GetEntityCoords(Ped)
	local GamePool = GetGamePool("CVehicle")

	for _,Entity in ipairs(GamePool) do
		local EntityCoords = GetEntityCoords(Entity)
		local EntityDistance = #(Coords - EntityCoords)

		if EntityDistance < Radius then
			Selected = Entity
			Radius = EntityDistance
			Model = GetEntityArchetypeName(Selected)
		end
	end

	return Selected,Model
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- VEHICLELIST
-----------------------------------------------------------------------------------------------------------------------------------------
function tvRP.VehicleList(Radius)
	local Ped = PlayerPedId()
	local Vehicle = IsPedInAnyVehicle(Ped) and GetVehiclePedIsUsing(Ped) or tvRP.ClosestVehicle(Radius or 5.0)

	if Vehicle and DoesEntityExist(Vehicle) and IsEntityAVehicle(Vehicle) then
		return Vehicle,NetworkGetNetworkIdFromEntity(Vehicle),GetVehicleNumberPlateText(Vehicle),GetEntityArchetypeName(Vehicle),GetVehicleClass(Vehicle)
	end

	return nil,nil,"",nil,false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- VEHICLENAME
-----------------------------------------------------------------------------------------------------------------------------------------
function tvRP.VehicleName()
	local Ped = PlayerPedId()
	if IsPedInAnyVehicle(Ped) then
		local Vehicle = GetVehiclePedIsUsing(Ped)

		return GetEntityArchetypeName(Vehicle),NetworkGetNetworkIdFromEntity(Vehicle),GetVehicleNumberPlateText(Vehicle)
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- VEHICLEMODEL
-----------------------------------------------------------------------------------------------------------------------------------------
function tvRP.VehicleModel(Vehicle)
	return GetEntityArchetypeName(Vehicle)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- LASTVEHICLE
-----------------------------------------------------------------------------------------------------------------------------------------
function tvRP.LastVehicle(Name)
	local Vehicle = GetLastDrivenVehicle()
	if Vehicle and DoesEntityExist(Vehicle) and Name == GetEntityArchetypeName(Vehicle) then
		return true
	end

	return false
end