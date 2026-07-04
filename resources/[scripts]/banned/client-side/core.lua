-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local NextRevive = GetGameTimer()
local NextService = GetGameTimer()
local Center = vec3(-1670.08,-3168.85,13.99)
-----------------------------------------------------------------------------------------------------------------------------------------
-- POLYPRISON
-----------------------------------------------------------------------------------------------------------------------------------------
local Poly = PolyZone:Create({
	vec2(-1673.59,-3100.58),
	vec2(-1707.37,-3159.48),
	vec2(-1646.88,-3194.14),
	vec2(-1610.94,-3151.29),
	vec2(-1604.72,-3140.20)
},{ name = "Banned", minZ = Center.z - 5, maxZ = Center.z + 20 })
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADPRISON
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		if LocalPlayer.state.Banned then
			local Ped = PlayerPedId()
			local CurrentTimer = GetGameTimer()

			if CurrentTimer >= NextService then
				NextService = CurrentTimer + 60000
				TriggerServerEvent("banned:Service")
			end

			local Coords = GetEntityCoords(Ped)
			if not Poly:isPointInside(Coords) then
				FreezeEntityPosition(Ped,true)

				LoadScene(Center.x,Center.y,Center.z)
				RequestCollisionAtCoord(Center.x,Center.y,Center.z)
				SetEntityCoordsNoOffset(Ped,Center.x,Center.y,Center.z)
				while not HasCollisionLoadedAroundEntity(Ped) do
					RequestCollisionAtCoord(Center.x,Center.y,Center.z)
					Wait(100)
				end

				FreezeEntityPosition(Ped,false)
			end

			local Health = GetEntityHealth(Ped)
			if Health <= 100 and (not NextRevive or CurrentTimer >= NextRevive) then
				NextRevive = CurrentTimer + 60000

				SetTimeout(15000,function()
					FreezeEntityPosition(Ped,true)

					LoadScene(Center.x,Center.y,Center.z)
					RequestCollisionAtCoord(Center.x,Center.y,Center.z)
					SetEntityCoordsNoOffset(Ped,Center.x,Center.y,Center.z)

					while not HasCollisionLoadedAroundEntity(Ped) do
						RequestCollisionAtCoord(Center.x,Center.y,Center.z)
						Wait(100)
					end

					FreezeEntityPosition(Ped,false)
					exports.survival:Revive(200)
				end)
			end
		end

		Wait(1000)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ONCLIENTRESOURCESTOP
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("onClientResourceStop",function(Resource)
	if Resource == GetCurrentResourceName() then
		return false
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ONRESOURCESTOP
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("onResourceStop",function(Resource)
	if Resource == GetCurrentResourceName() then
		return false
	end
end)