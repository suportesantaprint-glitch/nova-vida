-----------------------------------------------------------------------------------------------------------------------------------------
-- ENGINE
-----------------------------------------------------------------------------------------------------------------------------------------
local Engine = {
	Delta = 0.0,
	Scale = 0.0,
	New = 1000.0,
	Last = 1000.0,
	Current = 1000.0
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- BODY
-----------------------------------------------------------------------------------------------------------------------------------------
local Body = {
	Delta = 0.0,
	Scale = 0.0,
	New = 1000.0,
	Last = 1000.0,
	Current = 1000.0
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Last = nil
local Same = false
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLASS
-----------------------------------------------------------------------------------------------------------------------------------------
local Class = {
	[0] = 1.5,
	[1] = 1.5,
	[2] = 1.5,
	[3] = 1.5,
	[4] = 1.5,
	[5] = 1.5,
	[6] = 1.5,
	[7] = 1.5,
	[8] = 1.5,
	[9] = 1.5,
	[10] = 1.5,
	[11] = 1.5,
	[12] = 1.5,
	[13] = 1.5,
	[14] = 0.0,
	[15] = 0.5,
	[16] = 0.5,
	[17] = 1.5,
	[18] = 1.5,
	[19] = 1.5,
	[20] = 1.5,
	[21] = 1.5,
	[22] = 1.5
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADHEALTHVEH
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		local TimeDistance = 999
		local Ped = PlayerPedId()
		if IsPedInAnyVehicle(Ped) then
			local Vehicle = GetVehiclePedIsUsing(Ped)
			local ClassId = GetVehicleClass(Vehicle)

			if ClassId ~= 13 and ClassId ~= 14 then
				TimeDistance = 1

				if Same then
					local Torque = (Engine.New < 900) and ((Engine.New + 200.0) / 1100) or 1.0
					SetVehicleEngineTorqueMultiplier(Vehicle,Torque)
				end

				if GetPedInVehicleSeat(Vehicle,-1) == Ped then
					local Roll = GetEntityRoll(Vehicle)
					if (Roll > 75.0 or Roll < -75.0) and (ClassId ~= 15 and ClassId ~= 16) then
						DisableControlAction(0,59,true)
						DisableControlAction(0,60,true)
					end
				end

				Engine.Current = GetVehicleEngineHealth(Vehicle)
				Engine.Current = math.min(Engine.Current,1000.0)
				Engine.Delta = Engine.Last - Engine.Current
				Engine.Scale = Engine.Delta * 0.6 * Class[ClassId + 1]
				Engine.New = Engine.Current

				Body.Current = GetVehicleBodyHealth(Vehicle)
				Body.Current = math.min(Body.Current,1000.0)
				Body.Delta = Body.Last - Body.Current
				Body.Scale = Body.Delta * 0.6 * Class[ClassId + 1]
				Body.New = Body.Current

				if Vehicle ~= Last then
					Same = false
				end

				if Same then
					if Engine.Current < 1000.0 or Body.Current < 1000.0 then
						local Combine = math.max(Engine.Scale,Body.Scale)
						if Combine > (Engine.Current - 100.0) then
							Combine = Combine * 0.7
						end

						if Combine > Engine.Current then
							Combine = Engine.Current - (210.0 / 5)
						end

						Engine.New = Engine.Last - Combine

						if Engine.New > 210.0 and Engine.New < 350.0 then
							Engine.New = Engine.New - (0.038 * 7.4)
						elseif Engine.New < 210.0 then
							Engine.New = Engine.New - (0.1 * 1.5)
						end

						Engine.New = math.max(Engine.New,0.0)
						Body.New = math.max(Body.New,0.0)
					end
				else
					Same = true
				end

				if Body.Current < 100.0 then
					Body.New = 100.0
				end

				if Engine.Current < 100.0 then
					Engine.New = 100.0
				end

				if Engine.New ~= Engine.Current then
					SetVehicleEngineHealth(Vehicle,Engine.New)
				end

				if Body.New ~= Body.Current then
					SetVehicleBodyHealth(Vehicle,Body.New)
				end

				Last = Vehicle
				Engine.Last = Engine.New
				Body.Last = Body.New
			end
		else
			Same = false
		end

		Wait(TimeDistance)
	end
end)