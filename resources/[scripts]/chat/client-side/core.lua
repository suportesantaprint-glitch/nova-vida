-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
vSERVER = Tunnel.getInterface("chat")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Active = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- BLOCK
-----------------------------------------------------------------------------------------------------------------------------------------
local Block = {
	"zap",
	"macaco",
	"preto",
	"arrombado",
	"viadinho",
	"urugutango",
	"gorila",
	"gorilla",
	"mongoloide",
	"bixa",
	"bicha",
	"traveco",
	"veveco",
	"boiola",
	"pau",
	"buceta",
	"gay",
	"piranha",
	"monkey",
	"vagabunda",
	"puta",
	"escroto",
	"piranha",
	"pretinho",
	"escurinho",
	"negrinho",
	"piranha"
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSTART
-----------------------------------------------------------------------------------------------------------------------------------------
for Permission,v in pairs(Groups) do
	if v.Chat then
		Active[Permission] = true
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHATEVENT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("ChatEvent",function()
	local Ped = PlayerPedId()
	local Local = LocalPlayer.state
	if not Local.Active or IsPauseMenuActive() or Local.Handcuff or Local.Carry or exports["lb-phone"]:IsOpen() or IsPedReloading(Ped) then
		return false
	end

	local Police = false
	local Tags = { "Importante","Ação" }
	for Permission in pairs(Active) do
		if Local[Permission] then
			Tags[#Tags + 1] = Permission

			if not Police and (Permission == "LSPD" or Permission == "BCSO") then
				Tags[#Tags + 1] = "Policia"
				Police = true
			end
		end
	end

	SendNUIMessage({ Action = "Chat", Payload = { Tags = Tags, Block = Block, Disabled = { "Importante" } } })
	SetNuiFocus(true,true)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHAT:CLIENTMESSAGE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("chat:ClientMessage")
AddEventHandler("chat:ClientMessage",function(Author,Message,Mode,Html,Highlight)
	SendNUIMessage({ Action = "Message", Payload = { Author = Author, Message = Message, Tag = Mode, Html = Html, Highlight = Highlight } })
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHATSUBMIT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("ChatSubmit",function(Data,Callback)
	if LocalPlayer.state.Active and Data.Message ~= "" then
		if Data.Message:sub(1,1) == "/" then
			ExecuteCommand(Data.Message:sub(2))
			SetNuiFocus(false,false)
		else
			TriggerServerEvent("chat:ServerMessage",Data.Tag,Data.Message)
		end
	end

	Callback("Ok")
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLOSE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Close",function(Data,Callback)
	SetNuiFocus(false,false)

	Callback("Ok")
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- KEYMAPPING
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterKeyMapping("ChatEvent","Abrir o chat.","keyboard","T")