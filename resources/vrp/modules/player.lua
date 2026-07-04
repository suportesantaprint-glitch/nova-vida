-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Spawns = {}
local Objects = {}
local Weapons = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHARACTERCHOSEN
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("CharacterChosen",function(Passport,source,Creation)
	local Identity = vRP.Identity(Passport)
	local Datatable = vRP.Datatable(Passport)
	if not Datatable or not Identity then return end

	if Creation then
		vRPC.NewLoadSceneStartSphere(source,CreatorCoords.xyz)

		for _,v in pairs(SpawnCoords) do
			vRPC.NewLoadSceneStartSphere(source,v)
		end
	end

	if Datatable.Pos then
		if not Datatable.Pos.x or not Datatable.Pos.y or not Datatable.Pos.z then
			Datatable.Pos = CreatorCoords.xyz
		end
	else
		Datatable.Pos = CreatorCoords.xyz
	end

	Datatable.Armour = Datatable.Armour or 0
	Datatable.Stress = Datatable.Stress or 0
	Datatable.Hunger = Datatable.Hunger or 100
	Datatable.Thirst = Datatable.Thirst or 100
	Datatable.Health = Datatable.Health or 200
	Datatable.Inventory = Datatable.Inventory or {}
	Datatable.Weight = Datatable.Weight or MinimumWeight

	vRPC.Skin(source,Identity.Skin)
	vRP.Armour(source,Datatable.Armour)
	vRPC.SetHealth(source,Datatable.Health,Datatable.Health <= 100)

	if not Creation then
		vRP.Teleport(source,Datatable.Pos.x,Datatable.Pos.y,Datatable.Pos.z)
	end

	TriggerClientEvent("hud:Thirst",source,Datatable.Thirst)
	TriggerClientEvent("hud:Hunger",source,Datatable.Hunger)
	TriggerClientEvent("hud:Stress",source,Datatable.Stress)

	if Creation then
		TriggerClientEvent("skinshop:Apply",source,vRP.UserData(Passport,"Clothings"),true)
		TriggerClientEvent("barbershop:Apply",source,vRP.UserData(Passport,"Barbershop"))
		TriggerClientEvent("tattooshop:Apply",source,vRP.UserData(Passport,"Tattooshop"))
		TriggerClientEvent("spawn:Finish",source,nil,CreatorCoords.w)
	else
		if Spawns[Passport] and Characters[source].Banned == 0 then
			exports.vrp:Bucket(source,"Exit")
			TriggerClientEvent("spawn:Finish",source)
		else
			TriggerClientEvent("spawn:Finish",source,Datatable.Pos)
		end
	end

	if Characters[source].Banned ~= 0 then
		Player(source).state:set("Banned",true,true)
		exports.vrp:Bucket(source,"Enter",Banned.Route)

		if Banned.Mute then
			TriggerClientEvent("pma-voice:Mute",source,true)
		end
	end

	Player(source).state:set("Name",Identity.Name.." "..Identity.Lastname,true)
	Player(source).state:set("Active",true,true)
	Player(source).state:set("Passport",Passport,true)

	TriggerClientEvent("vRP:Active",source,Passport,Identity.Name.." "..Identity.Lastname,Datatable.Inventory,Creation)
	TriggerEvent("Connect",Passport,source,not Spawns[Passport])
	GlobalState.Players = GetNumPlayerIndices()

	if not Spawns[Passport] then
		Spawns[Passport] = true
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DELETEOBJECT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("DeleteObject")
AddEventHandler("DeleteObject",function(Index,Weapon)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		if Objects[Passport] and Objects[Passport][Index] then
			Objects[Passport][Index] = nil
		end

		if Weapon and Weapons[Passport] and Weapons[Passport][Weapon] then
			Index = Weapons[Passport][Weapon]
			Weapons[Passport][Weapon] = nil
		end
	end

	TriggerEvent("DeleteObjectServer",Index)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DELETEOBJECTSERVER
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("DeleteObjectServer",function(Index)
	local Networked = NetworkGetEntityFromNetworkId(Index)
	if DoesEntityExist(Networked) and not IsPedAPlayer(Networked) and GetEntityType(Networked) == 3 then
		DeleteEntity(Networked)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DELETEPED
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("DeletePed")
AddEventHandler("DeletePed",function(Index)
	local Networked = NetworkGetEntityFromNetworkId(Index)
	if DoesEntityExist(Networked) and not IsPedAPlayer(Networked) and GetEntityType(Networked) == 1 then
		DeleteEntity(Networked)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DEBUGOBJECTS
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("DebugObjects",function(Passport)
	if Objects[Passport] then
		for Index,_ in pairs(Objects[Passport]) do
			TriggerEvent("DeleteObjectServer",Index)
		end

		Objects[Passport] = nil
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DEBUGWEAPONS
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("DebugWeapons",function(Passport,Ignore)
	if Weapons[Passport] then
		local source = vRP.Source(Passport)
		for Name,Network in pairs(Weapons[Passport]) do
			TriggerEvent("DeleteObjectServer",Network)

			if not Ignore then
				TriggerClientEvent("inventory:RemoveWeapon",source,Name)
			end
		end

		Weapons[Passport] = nil
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDAGRADETHIRST
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.UpgradeThirst(Passport,Amount)
	local source = vRP.Source(Passport)
	local Datatable = vRP.Datatable(Passport)
	if not (Datatable and source) then return end

	Datatable.Thirst = math.min(100,(Datatable.Thirst or 0) + parseInt(Amount))

	TriggerClientEvent("hud:Thirst",source,Datatable.Thirst)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPGRADEHUNGER
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.UpgradeHunger(Passport,Amount)
	local source = vRP.Source(Passport)
	local Datatable = vRP.Datatable(Passport)
	if not (Datatable and source) then return end

	Datatable.Hunger = math.min(100,(Datatable.Hunger or 0) + parseInt(Amount))

	TriggerClientEvent("hud:Hunger",source,Datatable.Hunger)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPGRADESTRESS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.UpgradeStress(Passport,Amount)
	local source = vRP.Source(Passport)
	local Datatable = vRP.Datatable(Passport)
	if not (Datatable and source) then return end

	Datatable.Stress = math.min(100,(Datatable.Stress or 0) + parseInt(Amount))

	TriggerClientEvent("hud:Stress",source,Datatable.Stress)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DOWNGRADETHIRST
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.DowngradeThirst(Passport,Amount)
	local source = vRP.Source(Passport)
	local Datatable = vRP.Datatable(Passport)
	if not (Datatable and source) then return end

	Datatable.Thirst = math.max(0,(Datatable.Thirst or 100) - parseInt(Amount))

	TriggerClientEvent("hud:Thirst",source,Datatable.Thirst)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DOWNGRADETHIRST
-----------------------------------------------------------------------------------------------------------------------------------------
function tvRP.DowngradeThirst()
	local source = source
	local Passport = vRP.Passport(source)
	local Datatable = vRP.Datatable(Passport)
	if not (Passport and Datatable and Characters[source]) then return end

	Datatable.Thirst = math.max(0,(Datatable.Thirst or 100) - 1)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DOWNGRADEHUNGER
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.DowngradeHunger(Passport,Amount)
	local source = vRP.Source(Passport)
	local Datatable = vRP.Datatable(Passport)
	if not (Datatable and source) then return end

	Datatable.Hunger = math.max(0,(Datatable.Hunger or 100) - parseInt(Amount))

	TriggerClientEvent("hud:Hunger",source,Datatable.Hunger)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DOWNGRADEHUNGER
-----------------------------------------------------------------------------------------------------------------------------------------
function tvRP.DowngradeHunger()
	local source = source
	local Passport = vRP.Passport(source)
	local Datatable = vRP.Datatable(Passport)

	if not (Passport and Datatable and Characters[source]) then return end

	Datatable.Hunger = math.max(0,(Datatable.Hunger or 100) - 1)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DOWNGRADESTRESS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.DowngradeStress(Passport,Amount)
	local source = vRP.Source(Passport)
	local Datatable = vRP.Datatable(Passport)
	if not source or not Datatable then return end

	Datatable.Stress = math.max(0,(Datatable.Stress or 0) - math.max(0,parseInt(Amount)))

	TriggerClientEvent("hud:Stress",source,Datatable.Stress)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GETHEALTH
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.GetHealth(source)
	local Ped = GetPlayerPed(source)
	return (Ped and DoesEntityExist(Ped) and Characters[source]) and GetEntityHealth(Ped) or 100
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MODELPLAYER
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.ModelPlayer(source)
	local Ped = GetPlayerPed(source)
	if Ped and DoesEntityExist(Ped) and Characters[source] then
		return (GetEntityModel(Ped) == GetHashKey("mp_f_freemode_01")) and "mp_f_freemode_01" or "mp_m_freemode_01"
	end

	return "mp_m_freemode_01"
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GETEXPERIENCE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.GetExperience(Passport,Work)
	local Datatable = vRP.Datatable(Passport)
	if Datatable then
		Datatable[Work] = Datatable[Work] or 0
	end

	return Datatable and Datatable[Work] or 0,ClassCategory(Datatable and Datatable[Work] or 0)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PUTEXPERIENCE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.PutExperience(Passport,Work,Number)
	local Datatable = vRP.Datatable(Passport)
	if Datatable then
		Datatable[Work] = Datatable[Work] or 0

		local CurrentLevel = Datatable[Work]
		local NewLevel = CurrentLevel + Number
		if UpperLevel[Work] then
			local AfterLevel = ClassCategory(NewLevel)
			local BeforeLevel = ClassCategory(CurrentLevel)
			if BeforeLevel ~= AfterLevel then
				local AfterKey = tostring(AfterLevel)
				if UpperLevel[Work][AfterKey] then
					for _,v in pairs(UpperLevel[Work][AfterKey]) do
						vRP.GenerateItem(Passport,v.Item,math.random(v.Min, v.Max),true)
					end
				end
			end
		end

		Datatable[Work] = NewLevel
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SETARMOUR
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.SetArmour(source,Amount)
	local Character = Characters[source]
	if not source or not Character then return end

	local Ped = GetPlayerPed(source)
	if DoesEntityExist(Ped) then
		local Armour = math.min(GetPedArmour(Ped) + Amount,100)
		SetPedArmour(Ped,Armour)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- ARMOUR
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.Armour(source,Amount)
	if not source or not Characters[source] then return end

	local Ped = GetPlayerPed(source)
	if DoesEntityExist(Ped) then
		SetPedArmour(Ped,Amount)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TELEPORT
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.Teleport(source,x,y,z)
	if source and Characters[source] then
		local Ped = GetPlayerPed(source)
		if DoesEntityExist(Ped) then
			SetEntityCoords(Ped,x + 0.0001,y + 0.0001,z + 0.0001,false,false,false,false)
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CREATION
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.Creation(source)
	if source and Characters[source] then
		local Ped = GetPlayerPed(source)
		if DoesEntityExist(Ped) then
			SetEntityCoords(Ped,SpawnCoords[math.random(#SpawnCoords)])
			exports.vrp:Bucket(source,"Exit")
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- HEADING
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.Heading(source, Heading)
	local Ped = GetPlayerPed(source)
	if source and Characters[source] and DoesEntityExist(Ped) then
		SetEntityHeading(Ped,Heading)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GETENTITYCOORDS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.GetEntityCoords(source)
	local Ped = GetPlayerPed(source)
	return (source and Characters[source] and DoesEntityExist(Ped)) and GetEntityCoords(Ped) or vec3(0,0,0)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INSIDEVEHICLE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.InsideVehicle(source)
	local Ped = GetPlayerPed(source)
	return source and Characters[source] and DoesEntityExist(Ped) and GetVehiclePedIsIn(Ped) ~= 0 or false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INSIDEVEHICLEPASSAGER
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.InsideVehiclePassager(source)
	local Ped = GetPlayerPed(source)
	return source and Characters[source] and DoesEntityExist(Ped) and GetVehiclePedIsIn(Ped) ~= 0 and GetPedInVehicleSeat(GetVehiclePedIsIn(Ped),0) == Ped or false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DOESENTITYEXIST
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.DoesEntityExist(source)
	return source and Characters[source] and DoesEntityExist(GetPlayerPed(source)) or false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- ISENTITYVISIBLE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.IsEntityVisible(source)
	if source and Characters[source] then
		local Ped = GetPlayerPed(source)
		if DoesEntityExist(Ped) and not IsEntityVisible(Ped) then
			return true
		end
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CREATEMODELS
-----------------------------------------------------------------------------------------------------------------------------------------
function tvRP.CreateModels(Model,x,y,z,Type)
	local Hash = GetHashKey(Model)
	local Route = GetPlayerRoutingBucket(source)
	local Ped = CreatePed(Type or 4,Hash,x,y,z,true,true)

	local CurrentTime = os.time()
	while not DoesEntityExist(Ped) and (os.time() - CurrentTime) < 5 do
		Wait(1)
	end

	if DoesEntityExist(Ped) then
		SetEntityRoutingBucket(Ped,Route)
		SetEntityIgnoreRequestControlFilter(Ped,true)

		return NetworkGetNetworkIdFromEntity(Ped)
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CREATEOBJECT
-----------------------------------------------------------------------------------------------------------------------------------------
function tvRP.CreateObject(Model,x,y,z,Weapon,Component)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and Model then
		local Hash = GetHashKey(Model)
		local Object = CreateObject(Component or Hash,x,y,z - 2.0,true,true,false)

		local CurrentTime = os.time()
		while not DoesEntityExist(Object) and (os.time() - CurrentTime) < 5 do
			Wait(1)
		end

		if DoesEntityExist(Object) then
			SetEntityIgnoreRequestControlFilter(Object,true)

			local NetObjects = NetworkGetNetworkIdFromEntity(Object)

			if Weapon then
				Weapons[Passport] = Weapons[Passport] or {}
				Weapons[Passport][Weapon] = NetObjects
			else
				Objects[Passport] = Objects[Passport] or {}
				Objects[Passport][NetObjects] = true
			end

			return NetObjects
		end
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- BUCKET
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Bucket",function(source,Mode,Route)
	local Mode = Mode
	local Route = Route
	local source = source

	if Mode == "Enter" then
		SetPlayerRoutingBucket(source,Route)
		Player(source).state.Route = Route

		if Route > 0 then
			SetRoutingBucketEntityLockdownMode(Route,"strict")
			SetRoutingBucketPopulationEnabled(Route,false)
		end
	else
		SetPlayerRoutingBucket(source,0)
		Player(source).state.Route = 0
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP:RELOADWEAPONS
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("vRP:ReloadWeapons",function(source)
	local source = source
	local Passport = vRP.Passport(source)
	local Inventory = vRP.Inventory(Passport)
	if Passport and Inventory then
		for _,v in pairs(Inventory) do
			if exports.vrp:ItemTypeCheck(v.item,"Armamento") and not vRP.CheckDamaged(v.item) then
				TriggerClientEvent("inventory:CreateWeapon",source,v.item)
			end
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP:WAITCHARACTERS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("vRP:WaitCharacters")
AddEventHandler("vRP:WaitCharacters",function()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		if Characters[source] and Characters[source].Banned == 0 then
			exports.vrp:Bucket(source,"Exit")
		else
			TriggerClientEvent("Notify",source,ServerName,"Restam "..parseInt(Characters[source].Banned).." minutos de reclusão.","server",10000)
		end

		TriggerEvent("vRP:ReloadWeapons",source)

		if Characters[source] and Characters[source].Prison > 0 then
			Player(source).state.Prison = true
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- BARBERSHOP
-----------------------------------------------------------------------------------------------------------------------------------------
function tvRP.Barbershop(Barbershop)
	local source = source
	local Ped = GetPlayerPed(source)
	if Ped and DoesEntityExist(Ped) then
		SetPedHeadBlendData(Ped,Barbershop[1],Barbershop[2],0,Barbershop[53],Barbershop[54],0,Barbershop[3] + 0.0,Barbershop[5] + 0.0,0,false)

		SetPedEyeColor(Ped,Barbershop[4])

		SetPedComponentVariation(Ped,2,Barbershop[10],0,0)
		SetPedHairTint(Ped,Barbershop[11],Barbershop[12])

		SetPedHeadOverlay(Ped,0,Barbershop[7],1.0)
		SetPedHeadOverlayColor(Ped,0,0,0,0)

		SetPedHeadOverlay(Ped,1,Barbershop[22],Barbershop[23] + 0.0)
		SetPedHeadOverlayColor(Ped,1,1,Barbershop[24],Barbershop[24])

		SetPedHeadOverlay(Ped,2,Barbershop[19],Barbershop[20] + 0.0)
		SetPedHeadOverlayColor(Ped,2,1,Barbershop[21],Barbershop[21])

		SetPedHeadOverlay(Ped,3,Barbershop[9],1.0)
		SetPedHeadOverlayColor(Ped,3,0,0,0)

		SetPedHeadOverlay(Ped,4,Barbershop[13],Barbershop[14] + 0.0)
		SetPedHeadOverlayColor(Ped,4,0,0,0)

		SetPedHeadOverlay(Ped,5,Barbershop[25],Barbershop[26] + 0.0)
		SetPedHeadOverlayColor(Ped,5,2,Barbershop[27],Barbershop[27])

		SetPedHeadOverlay(Ped,6,Barbershop[6],1.0)
		SetPedHeadOverlayColor(Ped,6,0,0,0)

		SetPedHeadOverlay(Ped,7,Barbershop[52],1.0)
		SetPedHeadOverlayColor(Ped,7,0,0,0)

		SetPedHeadOverlay(Ped,8,Barbershop[16],Barbershop[17] + 0.0)
		SetPedHeadOverlayColor(Ped,8,2,Barbershop[18],Barbershop[18])

		SetPedHeadOverlay(Ped,9,Barbershop[8],1.0)
		SetPedHeadOverlayColor(Ped,9,0,0,0)

		SetPedHeadOverlay(Ped,10,Barbershop[47],Barbershop[48] + 0.0)
		SetPedHeadOverlayColor(Ped,10,1,Barbershop[49],Barbershop[49])

		SetPedHeadOverlay(Ped,11,Barbershop[55],1.0)
		SetPedHeadOverlayColor(Ped,7,0,0,0)

		SetPedHeadOverlay(Ped,12,Barbershop[56],1.0)
		SetPedHeadOverlayColor(Ped,7,0,0,0)

		SetPedFaceFeature(Ped,0,Barbershop[28] + 0.0)
		SetPedFaceFeature(Ped,1,Barbershop[29] + 0.0)
		SetPedFaceFeature(Ped,2,Barbershop[30] + 0.0)
		SetPedFaceFeature(Ped,3,Barbershop[31] + 0.0)
		SetPedFaceFeature(Ped,4,Barbershop[32] + 0.0)
		SetPedFaceFeature(Ped,5,Barbershop[33] + 0.0)
		SetPedFaceFeature(Ped,6,Barbershop[44] + 0.0)
		SetPedFaceFeature(Ped,7,Barbershop[34] + 0.0)
		SetPedFaceFeature(Ped,8,Barbershop[36] + 0.0)
		SetPedFaceFeature(Ped,9,Barbershop[35] + 0.0)
		SetPedFaceFeature(Ped,10,Barbershop[45] + 0.0)
		SetPedFaceFeature(Ped,11,Barbershop[15] + 0.0)
		SetPedFaceFeature(Ped,12,Barbershop[42] + 0.0)
		SetPedFaceFeature(Ped,13,Barbershop[46] + 0.0)
		SetPedFaceFeature(Ped,14,Barbershop[37] + 0.0)
		SetPedFaceFeature(Ped,15,Barbershop[38] + 0.0)
		SetPedFaceFeature(Ped,16,Barbershop[40] + 0.0)
		SetPedFaceFeature(Ped,17,Barbershop[39] + 0.0)
		SetPedFaceFeature(Ped,18,Barbershop[41] + 0.0)
		SetPedFaceFeature(Ped,19,Barbershop[43] + 0.0)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport,source)
	GlobalState.Players = GetNumPlayerIndices()

	TriggerEvent("DebugWeapons",Passport,true)
	TriggerEvent("DebugObjects",Passport)
end)