-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
vSERVER = Tunnel.getInterface("taxi")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Blip = nil
local Current = nil
local Passenger = nil
local Service = false
local Walking = false
local PaymentActive = false
local Lasted = math.random(#Locations)
local Selected = math.random(#Locations)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSERVERSTART
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	exports.target:AddBoxZone("WorkTaxi",Init.xyz,0.75,0.75,{
		name = "WorkTaxi",
		heading = Init.w,
		minZ = Init.z - 1.0,
		maxZ = Init.z + 1.0
	},{
		Distance = 1.75,
		options = {
			{
				event = "taxi:Init",
				label = "Iniciar Expediente",
				tunnel = "client"
			}
		}
	})
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- TAXI:INIT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("taxi:Init",function()
	Walking = false
	PaymentActive = false

	if DoesBlipExist(Blip) then
		RemoveBlip(Blip)
		Blip = nil
	end

	if Current and DoesEntityExist(Current) then
		SetPedKeepTask(Current,false)
		SetEntityAsMissionEntity(Current,false,false)
		TriggerServerEvent("DeletePed",NetworkGetNetworkIdFromEntity(Current))
	end

	if Passenger and DoesEntityExist(Passenger) then
		SetPedKeepTask(Passenger,false)
		SetEntityAsMissionEntity(Passenger,false,false)
		TriggerServerEvent("DeletePed",Passenger)
	end

	Current = nil
	Passenger = nil

	if Service then
		TriggerEvent("Notify","Central de Empregos","Você acaba finalizar sua jornada de trabalho, esperamos que você tenha aprendido bastante hoje.","default",5000)
		exports.target:LabelText("WorkTaxi","Iniciar Expediente")
		Service = false
	else
		TriggerEvent("Notify","Central de Empregos","Você acaba de dar inicio a sua jornada de trabalho, lembrando que a sua vida não se resume só a isso.","default",5000)
		exports.target:LabelText("WorkTaxi","Finalizar Expediente")
		MarkedPassenger()
		Service = true
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSYSTEM
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		local TimeDistance = 999
		local Ped = PlayerPedId()
		if Service and IsPedInAnyVehicle(Ped) then
			local Vehicle = GetVehiclePedIsUsing(Ped)
			if GetEntityArchetypeName(Vehicle) == "taxi" then
				local Coords = GetEntityCoords(Ped)
				local OtherCoords = Locations[Selected].Vehicle
				local Distance = #(Coords - OtherCoords)
				if Distance <= 100.0 and not Walking then
					TimeDistance = 1
					DrawMarker(21,OtherCoords.x,OtherCoords.y,OtherCoords.z,0.0,0.0,0.0,0.0,180.0,130.0,1.5,1.5,1.0,88,101,242,175,false,true,0,true)

					if Distance <= 2.5 and IsControlJustPressed(1,38) then
						if PaymentActive then
							FreezeEntityPosition(Vehicle,true)

							if Current and DoesEntityExist(Current) then
								Passenger = NetworkGetNetworkIdFromEntity(Current)

								TaskLeaveVehicle(Current,Vehicle,1)
								TaskWanderStandard(Current,10.0,10)
								vSERVER.Payment(Selected)
							end

							FreezeEntityPosition(Vehicle,false)
							PaymentActive = false
							Lasted = Selected

							repeat
								Selected = math.random(#Locations)
							until Selected ~= Lasted

							MarkedPassenger()

							SetTimeout(10000,function()
								if Passenger then
									SetPedKeepTask(Passenger,false)
									SetEntityAsMissionEntity(Passenger,false,false)
									TriggerServerEvent("DeletePed",Passenger)
									Passenger = nil
								end
							end)
						else
							CreatePassenger(Vehicle)
						end
					end
				end
			end
		end

		Wait(TimeDistance)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CREATEPASSENGER
-----------------------------------------------------------------------------------------------------------------------------------------
function CreatePassenger(Vehicle)
	if Passenger and DoesEntityExist(Passenger) then
		SetPedKeepTask(Passenger,false)
		SetEntityAsMissionEntity(Passenger,false,false)
		TriggerServerEvent("DeletePed",NetworkGetNetworkIdFromEntity(Passenger))
	end

	if Current and DoesEntityExist(Current) then
		SetPedKeepTask(Current,false)
		SetEntityAsMissionEntity(Current,false,false)
		TriggerServerEvent("DeletePed",NetworkGetNetworkIdFromEntity(Current))
	end

	Current = nil
	Passenger = nil

	local Rand = math.random(#Models)
	if LoadModel(Models[Rand]) then
		Current = CreatePed(26,Models[Rand],Locations[Selected].Ped.x,Locations[Selected].Ped.y,Locations[Selected].Ped.z,0.0,true,false)

		SetEntityCoordsNoOffset(Current,Locations[Selected].Ped.x,Locations[Selected].Ped.y,Locations[Selected].Ped.z)
		LocalPlayer["state"]:set("BlockLocked",true,false)
		SetBlockingOfNonTemporaryEvents(Current,true)
		SetEntityAsMissionEntity(Current,true,true)
		DecorSetBool(Current,"CREATIVE_PED",true)
		FreezeEntityPosition(Vehicle,true)
		SetEntityInvincible(Current,true)
		SetVehicleDoorsLocked(Vehicle,1)
		SetPedKeepTask(Current,true)
		Walking = true

		TaskGoToEntity(Current,Vehicle,-1,3.0,1.0,1073741824,0)

		while not IsPedSittingInVehicle(Current,Vehicle) do
			TaskEnterVehicle(Current,Vehicle,-1,2,1.0,1,0)
			Wait(1000)
		end

		LocalPlayer["state"]:set("BlockLocked",false,false)
		FreezeEntityPosition(Vehicle,false)
		Lasted = Selected

		repeat
			Selected = math.random(#Locations)
		until Selected ~= Lasted

		Walking = false
		MarkedPassenger()
		PaymentActive = true
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MARKEDPASSENGER
-----------------------------------------------------------------------------------------------------------------------------------------
function MarkedPassenger()
	if DoesBlipExist(Blip) then
		RemoveBlip(Blip)
		Blip = nil
	end

	Blip = AddBlipForCoord(Locations[Selected].Vehicle.x,Locations[Selected].Vehicle.y,Locations[Selected].Vehicle.z)
	SetBlipSprite(Blip,1)
	SetBlipDisplay(Blip,4)
	SetBlipAsShortRange(Blip,true)
	SetBlipColour(Blip,77)
	SetBlipScale(Blip,0.75)
	SetBlipRoute(Blip,true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString("Taxista")
	EndTextCommandSetBlipName(Blip)
end