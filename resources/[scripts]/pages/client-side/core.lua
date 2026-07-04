-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Pages = {}
local Exists = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADINIT
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		if LocalPlayer.state.Active then
			local Ped = PlayerPedId()
			local Coords = GetEntityCoords(Ped)

			for Index,v in pairs(Pages) do
				if v.Route == LocalPlayer.state.Route then
					local OtherCoords = vec3(v.Coords[1],v.Coords[2],v.Coords[3])
					if #(Coords - OtherCoords) <= 10 then
						if not Exists[Index] then
							exports.target:AddCircleZone("Pages:"..Index,OtherCoords,0.2,{
								name = "Pages:"..Index,
								heading = 0.0,
								useZ = true
							},{
								shop = Index,
								Distance = v.Distance,
								options = LocalPlayer.state.Admin and {
									{ event = "pages:Send", label = "Abrir", tunnel = "client" },
									{ event = "pages:Delete", label = "Deletar", tunnel = "server" }
								} or {
									{ event = "pages:Send", label = "Abrir", tunnel = "client" }
								}
							})

							Exists[Index] = true
						end
					elseif Exists[Index] then
						ClearExist(Index)
					end
				elseif Exists[Index] then
					ClearExist(Index)
				end
			end
		end

		Wait(1000)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLEAREXIST
-----------------------------------------------------------------------------------------------------------------------------------------
function ClearExist(Selected)
	if Exists[Selected] then
		exports.target:RemCircleZone("Pages:"..Selected)
		Exists[Selected] = nil
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PAGES:SEND
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("pages:Send",function(Index)
	if Pages[Index] and Pages[Index].Image then
		SetNuiFocus(true,true)
		TransitionToBlurred(1000)
		TriggerEvent("hud:Active",false)
		SendNUIMessage({ Action = "Open", Payload = Pages[Index].Image })
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLOSE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Close",function(Data,Callback)
	SetNuiFocus(false,false)
	TransitionFromBlurred(1000)
	TriggerEvent("hud:Active",true)

    Callback("Ok")
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PAGES:NEW
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("pages:New")
AddEventHandler("pages:New",function(Selected,Data)
	Pages[Selected] = Data
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PAGES:REMOVE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("pages:Remove")
AddEventHandler("pages:Remove",function(Selected)
	ClearExist(Selected)
	Pages[Selected] = nil
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PAGES:TABLE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("pages:Table")
AddEventHandler("pages:Table",function(Data)
	Pages = Data
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PAGES:ITEM
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("pages:Item")
AddEventHandler("pages:Item",function(Link)
	SetNuiFocus(true,true)
	TransitionToBlurred(1000)
	TriggerEvent("hud:Active",false)
	SendNUIMessage({ Action = "Open", Payload = Link })
end)