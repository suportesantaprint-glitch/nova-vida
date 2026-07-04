-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Object = nil
local Model = "vw_prop_vw_luckywheel_02a"
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADCASSINO
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	LoadModel(Model)

	while true do
		local TimeDistance = 999
		local Ped = PlayerPedId()
		if not IsPedInAnyVehicle(Ped) then
			local Coords = GetEntityCoords(Ped)
			if #(Coords - Wheel.xyz) <= 50 then
				if not Object then
					Object = CreateObjectNoOffset(Model,Wheel.xyz,false,false,false)
					SetEntityHeading(Object,Wheel.w)
				end
			elseif Object then
				if DoesEntityExist(Object) then
					DeleteEntity(Object)
				end

				Object = nil
			end
		end

		Wait(TimeDistance)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- START
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("luckywheel:Start")
AddEventHandler("luckywheel:Start",function(Result)
	if not Result or not Object or not DoesEntityExist(Object) then
		return false
	end

	SetEntityRotation(Object,0.0,0.0,0.0,2,true)

	CreateThread(function()
		local RollingSpeed
		local RollingRatio = 1.0
		local TargetAngle = (Result - 1) * 18
		local TotalRotation = TargetAngle + (360 * 8)
		local HalfRotation = TotalRotation / 2

		while RollingRatio > 0 do
			if TotalRotation > HalfRotation then
				RollingRatio = RollingRatio + 1
			else
				RollingRatio = RollingRatio - 1
			end

			RollingRatio = math.max(RollingRatio,0)
			RollingSpeed = RollingRatio / 200
			TotalRotation = TotalRotation - RollingSpeed

			local CurrentRotation = GetEntityRotation(Object,2)

			SetEntityRotation(Object,0.0,(CurrentRotation.y - RollingSpeed),Wheel.w,2,true)

			Wait(0)
		end
	end)
end)