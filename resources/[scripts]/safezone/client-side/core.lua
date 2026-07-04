-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local LastVehicle = nil
-----------------------------------------------------------------------------------------------------------------------------------------
-- SAFEZONES
-----------------------------------------------------------------------------------------------------------------------------------------
local SafeZones = {
	PolyZone:Create({
		vec2(82.08,-1122.75),
		vec2(79.52,-1122.14),
		vec2(77.23,-1119.89),
		vec2(76.29,-1117.00),
		vec2(76.84,-1111.80),
		vec2(79.84,-1100.71),
		vec2(88.48,-1078.39),
		vec2(103.6,-1045.46),
		vec2(112.63,-1023.3),
		vec2(160.21,-892.64),
		vec2(162.80,-887.15),
		vec2(168.32,-879.56),
		vec2(174.47,-867.66),
		vec2(183.88,-843.83),
		vec2(186.26,-840.89),
		vec2(191.49,-840.09),
		vec2(260.51,-865.31),
		vec2(263.73,-867.77),
		vec2(265.97,-872.41),
		vec2(265.69,-877.52),
		vec2(201.08,-1055.44),
		vec2(198.93,-1065.38),
		vec2(197.91,-1077.94),
		vec2(196.65,-1108.07),
		vec2(195.70,-1112.14),
		vec2(192.62,-1117.41),
		vec2(187.76,-1121.44),
		vec2(178.91,-1123.74)
	},{ name = "1" }),
	PolyZone:Create({
		vec2(5588.77,13887.28),
		vec2(5477.89,13777.98),
		vec2(5383.17,13902.15),
		vec2(5480.4,13984.92)
	},{ name = "Banned", minZ = 8.99, maxZ = 33.99 })
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSYSTEM
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		local Inside = false
		local Ped = PlayerPedId()
		local Coords = GetEntityCoords(Ped)

		for Index,Poly in ipairs(SafeZones) do
			if Poly:isPointInside(Coords) then
				Inside = Index
				break
			end
		end

		local SafeState = LocalPlayer.state.Safezone
		if Inside and not SafeState then
			LocalPlayer.state:set("Safezone",Inside,true)
			NetworkSetFriendlyFireOption(false)
			SetEntityInvincible(Ped,true)
			SetLocalPlayerAsGhost(true)

			if IsPedArmed(Ped,7) then
				TriggerEvent("inventory:CleanWeapons")
			end
		elseif not Inside and SafeState then
			SetLocalPlayerAsGhost(false)
			SetEntityInvincible(Ped,false)
			NetworkSetFriendlyFireOption(true)
			LocalPlayer.state:set("Safezone",false,true)
		end

		Wait(1000)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADZONE
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		local TimeDistance = 999
		local Ped = PlayerPedId()

		if LocalPlayer.state.Safezone then
			TimeDistance = 0

			DisableControlAction(0,24,true)
			DisableControlAction(0,25,true)
			DisableControlAction(0,68,true)
			DisableControlAction(0,69,true)
			DisableControlAction(0,70,true)
			DisableControlAction(0,91,true)
			DisableControlAction(0,92,true)
			DisableControlAction(0,140,true)
			DisableControlAction(0,142,true)
			DisableControlAction(0,257,true)
			DisablePlayerFiring(Ped,true)

			local Vehicle = GetVehiclePedIsIn(Ped)
			if Vehicle > 0 then
				if LastVehicle ~= Vehicle then
					if LastVehicle and DoesEntityExist(LastVehicle) then
						SetNetworkVehicleAsGhost(LastVehicle,false)
					end

					LastVehicle = Vehicle
					SetNetworkVehicleAsGhost(Vehicle,true)
				end
			elseif LastVehicle then
				if DoesEntityExist(LastVehicle) then
					SetNetworkVehicleAsGhost(LastVehicle,false)
				end

				LastVehicle = nil
			end
		elseif LastVehicle then
			if DoesEntityExist(LastVehicle) then
				SetNetworkVehicleAsGhost(LastVehicle,false)
			end

			LastVehicle = nil
		end

		Wait(TimeDistance)
	end
end)