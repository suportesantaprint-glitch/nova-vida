-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP:ACTIVE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("vRP:Active")
AddEventHandler("vRP:Active",function(Passport,Name)
	SetDiscordAppId(1518809055177474088)
	SetDiscordRichPresenceAsset("Nova Vida RP")
	SetRichPresence("#"..Passport.." "..Name)
	SetDiscordRichPresenceAssetText("Nova Vida Rp")
	SetDiscordRichPresenceAssetSmall("Nova Vida RP")
	SetDiscordRichPresenceAssetSmallText("Nova Vida RP")
	SetDiscordRichPresenceAction(0,"Discord","https://discord.gg/WhYpj6utPf")
end)