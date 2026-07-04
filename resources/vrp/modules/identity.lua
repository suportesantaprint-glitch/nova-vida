-----------------------------------------------------------------------------------------------------------------------------------------
-- IDENTITY
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.Identity(Passport)
	local Passport = parseInt(Passport)
	local source = vRP.Source(Passport)

	return Characters[source] or vRP.SingleQuery("characters/Person",{ Passport = Passport })
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- FULLNAME
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.FullName(Passport)
	local Passport = parseInt(Passport)
	local Identity = vRP.Identity(Passport)

	return Identity and (Identity.Name.." "..Identity.Lastname) or NameDefault
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- LOWERNAME
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.LowerName(Passport)
	local Passport = parseInt(Passport)
	local Identity = vRP.Identity(Passport)

	return Identity and Identity.Name or SplitOne(NameDefault," ")
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- AVATAR
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Avatar",function(Passport,Permission)
    if not Passport then
        return ""
    end
    
    local Consult
    
    if Permission then
        Consult = exports.oxmysql:single_async("SELECT Image FROM avatars WHERE Passport = ? AND Permission = ? LIMIT 1",{ Passport, Permission })
    else
        Consult = exports.oxmysql:single_async("SELECT Image FROM avatars WHERE Passport = ? ORDER BY id DESC LIMIT 1",{ Passport })
    end

    return Consult and Consult.Image or ""
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- LICENSE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.License(Passport)
	local Passport = parseInt(Passport)
	local Identity = vRP.Identity(Passport)

	return Identity and Identity.License or 0
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INSERTPRISON
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.InsertPrison(Passport,Amount)
	local Amount = parseInt(Amount)
	local Passport = parseInt(Passport)

	if Amount > 0 then
		vRP.Query("characters/InsertPrison",{ Passport = Passport, Prison = Amount })

		local source = vRP.Source(Passport)
		if Characters[source] then
			Characters[source].Prison = (Characters[source].Prison or 0) + Amount
			Player(source).state.Prison = true
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATEPRISON
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.UpdatePrison(Passport,Amount)
    local Amount = parseInt(Amount)
    local Passport = parseInt(Passport)
	local Identity = vRP.Identity(Passport)

    if Amount > 0 then
        vRP.Query("characters/ReducePrison",{ Passport = Passport, Prison = Amount })

        local source = vRP.Source(Passport)
        if Characters[source] then
            Characters[source].Prison = math.max((Characters[source].Prison or 0) - Amount,0)
            Player(source).state.Prison = Characters[source].Prison > 0

            if Identity then
                if Identity.Prison <= 0 then
                    vRP.Teleport(source,PrisonCoords)
                    TriggerClientEvent("Notify",source,"Boolingbroke","Serviços finalizados.","policia",5000)
                else
                    TriggerClientEvent("Notify",source,"Boolingbroke","Reduzimos "..Amount.." serviços, restando um total de "..Identity.Prison..".","policia",5000)
                end
            end
        end
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- UPGRADECHARACTERS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.UpgradeCharacters(source)
	if Characters[source] then
		vRP.Query("accounts/UpdateCharacters",{ License = Characters[source].License })
		Characters[source].Characters = Characters[source].Characters + 1
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- USERGEMSTONE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.UserGemstone(License)
	return vRP.Account(License).Gemstone or 0
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPGRADEGEMSTONE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.UpgradeGemstone(Passport,Amount,SendLicense)
	local Amount = parseInt(Amount)
	local Passport = parseInt(Passport)
	local Identity = vRP.Identity(Passport)
	if Amount > 0 and Identity then
		vRP.Query("accounts/AddGemstone",{ License = Identity.License, Gemstone = Amount })

		if DiscordBot and SendLicense then
			local Account = vRP.Account(Identity.License)
			exports.discord:Content("Gemstone",Account.Discord.." Obrigado por sua contribuição ao **"..ServerName.."**, seus **"..Dotted(Amount).."x Diamantes** foram creditados em sua conta.")
		end

		local source = vRP.Source(Passport)
		if Characters[source] then
			TriggerClientEvent("hud:AddGemstone",source,Amount)
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPGRADENAMES
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.UpgradeNames(Passport,Name,Lastname)
	local Passport = parseInt(Passport)
	local source = vRP.Source(Passport)

	if Characters[source] then
		Characters[source].Name = Name
		Characters[source].Lastname = Lastname
	end

	vRP.Query("characters/UpdateName",{ Name = Name, Lastname = Lastname, Passport = Passport })
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PASSPORTPLATE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.PassportPlate(Plate)
	local Consult = vRP.SingleQuery("vehicles/plateVehicles",{ Plate = Plate })
	return Consult and Consult.Passport or false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GENERATEPLATE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.GeneratePlate()
	repeat
		Plate = GenerateString("DDLLLDDD")
	until Plate and not vRP.PassportPlate(Plate)

	return Plate
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GENERATETOKEN
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.GenerateToken()
	repeat
		Token = GenerateString("DDDDDDD")
	until Token and not vRP.SingleQuery("accounts/Token",{ Token = Token })

	return Token
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GENERATEHASH
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.GenerateHash(Index)
	repeat
		Hash = GenerateString("DDLLDDLL")
	until Hash and not vRP.SingleQuery("entitydata/GetData",{ Name = Index..":"..Hash })

	return Hash
end