-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
vSERVER = Tunnel.getInterface("securitycam")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Objects = {}
local Camera = nil
local Heading = 0.0
local MouseSpeed = 0.2
local Cooldown = GetGameTimer()
local CameraRot = vec3(0.0,0.0,0.0)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSERVERSTART
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	for Index,v in pairs(Locations) do
		exports.target:AddCircleZone("SecurityCam:"..Index,v.Coords,0.1,{
			name = "SecurityCam:"..Index,
			heading = 0.0,
			useZ = true
		},{
			Distance = v.Distance,
			options = {
				{
					event = "securitycam:Open",
					label = v.Hacker and "Hackear" or "Abrir",
					tunnel = "products",
					service = Index
				}, v.Hacker and {
					event = "securitycam:Inative",
					label = "Desativar",
					tunnel = "client"
				}
			}
		})
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- OBJECTS:TABLE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("objects:Table")
AddEventHandler("objects:Table",function(Table)
	for Number,v in pairs(Table) do
		if v.Mode == "Camera" then
			Objects[Number] = v
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- OBJECTS:ADICIONAR
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("objects:Adicionar")
AddEventHandler("objects:Adicionar",function(Number,Table)
	if not Table or not Table.Mode or Table.Mode ~= "Camera" then
		return false
	end

	Objects[Number] = Table
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- OBJECTS:REMOVER
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("objects:Remover")
AddEventHandler("objects:Remover",function(Number)
	if Objects[Number] then
		Objects[Number] = nil
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLAMP
-----------------------------------------------------------------------------------------------------------------------------------------
function Clamp(Value,Minimal,Maximum)
	return math.max(Minimal,math.min(Maximum,Value))
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLAMYAWTORANGE
-----------------------------------------------------------------------------------------------------------------------------------------
function ClampYawToRange(Current,Minimal,Maximum)
	Current = (Current + 360.0) % 360.0
	Minimal = (Minimal + 360.0) % 360.0
	Maximum = (Maximum + 360.0) % 360.0

	if Minimal < Maximum then
		return Clamp(Current, Minimal, Maximum)
	else
		if Current > Maximum and Current < Minimal then
			if (Current - Maximum) < (Minimal - Current) then
				return Maximum
			else
				return Minimal
			end
		else
			return Current
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SECURITYCAM:INATIVE
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("securitycam:Inative",function()
	if not next(Objects) then
		TriggerEvent("Notify","Câmeras de Segurança","Nenhuma câmera encontrada no sistema.","vermelho",5000)
		return false
	end

	if not vSERVER.Connections() then
		TriggerEvent("Notify","Câmeras de Segurança","Sistema desativado temporariamente.","vermelho",5000)
		return false
	end

	if (HackerItem and not vSERVER.TakeItem()) or not exports.lettergame:LetterGame(LetterDuration,LetterSpeed) then
		return false
	end

	TriggerEvent("Notify","Câmeras de Segurança","Sistema desativado com sucesso.","verde",5000)
	vSERVER.Inative()
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SECURITYCAM:OPEN
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("securitycam:Open",function(Index)
	if not next(Objects) then
		TriggerEvent("Notify","Câmeras de Segurança","Nenhuma câmera encontrada no sistema.","vermelho",5000)
		return false
	end

	if not vSERVER.Connections() then
		TriggerEvent("Notify","Câmeras de Segurança","Sistema desativado temporariamente.","vermelho",5000)
		return false
	end

	local Selected = Locations[Index]
	if not Selected then
		return false
	end

	if Selected.Hacker and Cooldown <= GetGameTimer() then
		if (HackerItem and not vSERVER.TakeItem()) or not exports.lettergame:LetterGame(LetterDuration,LetterSpeed) then
			return false
		end

		Cooldown = GetGameTimer() + (HackerDuration * 60000)
	end

	if not Selected.Hacker and not CheckPolice() then
		return false
	end

	for Number,v in pairs(Objects) do
		local MinRoad,MinCross = GetStreetNameAtCoord(v.Coords[1],v.Coords[2],v.Coords[3])
		local FullRoad,FullCross = GetStreetNameFromHashKey(MinRoad),GetStreetNameFromHashKey(MinCross)
		exports.dynamic:AddButton(v.Name,FullRoad.."  |  "..FullCross,"securitycam:Selected",Number,false,false)
	end

	exports.dynamic:Open()
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SECURITYCAM:SELECTED
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("securitycam:Selected",function(Number)
	if not Objects[Number] then
		return false
	end

	TriggerEvent("dynamic:Close")

	if LocalPlayer.state.SecurityCam and Camera and DoesCamExist(Camera) then
		TriggerEvent("securitycam:Destroy")
	end

	local Selected = Objects[Number].Coords
	local Coords = GetOffsetFromCoordAndHeadingInWorldCoords(Selected[1],Selected[2],Selected[3] - 0.25,Selected[4],0.0,-0.05,0.0)

	Heading = (Selected[4] + 180.0) % 360.0
	NewLoadSceneStartSphere(Coords.xyz,250.0,2)
	CameraRot = vec3(-30.0,0.0,Heading)

	Camera = CreateCam("DEFAULT_SCRIPTED_CAMERA",true)
	SetCamCoord(Camera,Coords.x,Coords.y,Coords.z)
	RenderScriptCams(true,false,0,false,false)
	SetCamRot(Camera,CameraRot,2)
	SetCamActive(Camera,true)
	SetCamFov(Camera,60.0)

	LocalPlayer.state:set("SecurityCam",true,true)
	LocalPlayer.state:set("Commands",true,true)
	LocalPlayer.state:set("Buttons",true,true)

	SetTimecycleModifier("scanline_cam_cheap")
	SetTimecycleModifierStrength(2.0)
	TriggerEvent("hud:Active",false)

	CreateThread(function()
		while LocalPlayer.state.SecurityCam and Camera and DoesCamExist(Camera) do
			local XRel = GetDisabledControlNormal(0,1)
			local YRel = GetDisabledControlNormal(0,2)
			local NewPitch = Clamp(CameraRot.x - YRel * MouseSpeed * 10.0,-45.0,0.0)
			local NewYaw = CameraRot.z - XRel * MouseSpeed * 10.0
			local MinYaw = (Heading - 90.0) % 360.0
			local MaxYaw = (Heading + 90.0) % 360.0

			NewYaw = ClampYawToRange(NewYaw,MinYaw,MaxYaw)
			CameraRot = vec3(NewPitch,0.0,NewYaw)
			SetCamRot(Camera,CameraRot,2)

			Wait(0)
		end
	end)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SECURITYCAM:DESTROY
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("securitycam:Destroy")
AddEventHandler("securitycam:Destroy",function()
	if LocalPlayer.state.SecurityCam and Camera and DoesCamExist(Camera) then
		LocalPlayer.state:set("SecurityCam",false,true)
		LocalPlayer.state:set("Commands",false,true)
		LocalPlayer.state:set("Buttons",false,true)

		ClearTimecycleModifier("scanline_cam_cheap")
		RenderScriptCams(false,false,0,false,false)
		SetTimecycleModifierStrength(0.0)
		TriggerEvent("hud:Active",true)
		DestroyCam(Camera,false)
		Camera = nil
	end
end)