-----------------------------------------------------------------------------------------------------------------------------------------
-- LOADMODEL
-----------------------------------------------------------------------------------------------------------------------------------------
function LoadModel(Model)
	local Hash = type(Model) == "string" and GetHashKey(Model) or Model

	if not IsModelInCdimage(Hash) or not IsModelValid(Hash) then
		return false
	end

	if not HasModelLoaded(Hash) then
		RequestModel(Hash)

		local Timeout = GetGameTimer() + 10000
		while not HasModelLoaded(Hash) do
			if GetGameTimer() > Timeout then
				return false
			end

			Wait(0)
		end

		SetModelAsNoLongerNeeded(Hash)
	end

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- LOADANIM
-----------------------------------------------------------------------------------------------------------------------------------------
function LoadAnim(Dict)
	if not HasAnimDictLoaded(Dict) then
		RequestAnimDict(Dict)

		local Timeout = GetGameTimer() + 10000
		while not HasAnimDictLoaded(Dict) do
			if GetGameTimer() > Timeout then
				return false
			end

			Wait(0)
		end
	end

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- LOADTEXTURE
-----------------------------------------------------------------------------------------------------------------------------------------
function LoadTexture(Library)
	if not HasStreamedTextureDictLoaded(Library) then
		RequestStreamedTextureDict(Library,false)

		local Timeout = GetGameTimer() + 10000
		while not HasStreamedTextureDictLoaded(Library) do
			if GetGameTimer() > Timeout then
				return false
			end

			Wait(0)
		end
	end

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- LOADMOVEMENT
-----------------------------------------------------------------------------------------------------------------------------------------
function LoadMovement(Library)
	if not HasAnimSetLoaded(Library) then
		RequestAnimSet(Library)

		local Timeout = GetGameTimer() + 10000
		while not HasAnimSetLoaded(Library) do
			if GetGameTimer() > Timeout then
				return false
			end

			Wait(0)
		end
	end

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- LOADPTFXASSET
-----------------------------------------------------------------------------------------------------------------------------------------
function LoadPtfxAsset(Library)
	if not HasNamedPtfxAssetLoaded(Library) then
		RequestNamedPtfxAsset(Library)

		local Timeout = GetGameTimer() + 10000
		while not HasNamedPtfxAssetLoaded(Library) do
			if GetGameTimer() > Timeout then
				return false
			end

			Wait(0)
		end
	end

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- LOADNETWORK
-----------------------------------------------------------------------------------------------------------------------------------------
function LoadNetwork(Network)
	while not NetworkDoesEntityExistWithNetworkId(Network) do
		Wait(0)
	end

	local Entitys = NetToEnt(Network)
	if not DoesEntityExist(Entitys) then
		return false
	end

	local Timeout = GetGameTimer() + 10000
	NetworkRequestControlOfEntity(Entitys)
	while not NetworkHasControlOfEntity(Entitys) do
		if GetGameTimer() > Timeout then
			return false
		end

		Wait(0)
	end

	Timeout = GetGameTimer() + 10000
	SetEntityAsMissionEntity(Entitys,true,true)
	while not IsEntityAMissionEntity(Entitys) do
		if GetGameTimer() > Timeout then
			return false
		end

		Wait(0)
	end

	return Entitys,NetworkGetNetworkIdFromEntity(Entitys)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECKPOLICE
-----------------------------------------------------------------------------------------------------------------------------------------
function CheckPolice()
	return LocalPlayer.state.LSPD or LocalPlayer.state.BCSO or LocalPlayer.state.SAPR
end