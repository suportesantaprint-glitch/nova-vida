-----------------------------------------------------------------------------------------------------------------------------------------
-- BANNED
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.Banned(source,Account)
	local Return = false
	local Tokens = GetNumPlayerTokens(source)
	local Identities = GetPlayerIdentifiers(source)

	local function CheckAndInsert(Token)
		local Consult = vRP.SingleQuery("hwid/Check",{ Token = Token })

		if not Consult then
			vRP.Query("hwid/Insert",{ Token = Token, Account = Account.id })
		elseif Consult.Banned then
			if Consult.Account == Account.id then
				Return = Return or "User"
			else
				vRP.Query("hwid/Insert",{ Token = Token, Account = Account.id })
				Return = Return or { "Other",Consult.Account }
			end
		end
	end

	for _,v in pairs(Identities) do
		CheckAndInsert(v)
	end

	for Number = 0,(Tokens - 1) do
		local Token = GetPlayerToken(source,Number)
		if Token then
			CheckAndInsert(Token)
		end
	end

	if Account.Banned == -1 or Account.Banned > 0 then
		vRP.Query("hwid/All",{ Account = Account.id, Banned = 1 })
		Return = Return or "User"
	else
		vRP.Query("hwid/All",{ Account = Account.id, Banned = 0 })

		if Return == "User" then
			Return = false
		end
	end

	return Return
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SETBANNED
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.SetBanned(Passport,Amount,Mode,Reason)
	local function SendToDiscord(Passport,Mode,Amount,Reason,Discord)
		local Message = (Mode == "Permanente") and "Permanente" or Amount
		local Motivo = Reason or "Banimento administrativo"
		exports.discord:Embed("Ban","**[PASSAPORTE]:** "..Passport.."\n**[TEMPO]:** "..Message.."\n**[MOTIVO]:** "..Motivo.."\n**[DISCORD]:** <@"..Discord..">\n**[DATA & HORA]:** "..os.date("%d/%m/%Y").." às "..os.date("%H:%M"))
	end

	local Account = vRP.AccountOptimize(Passport)
	local Permanent = (Amount == -1 or Mode == "Permanente")
	local UseReason = Reason
	if not UseReason then
		if Mode ~= "Permanente" and Mode ~= "Horas" and Mode ~= "Dias" then
			UseReason = Mode
		end
	end
	UseReason = UseReason or "Banimento administrativo"

	vRP.Query("hwid/All",{ Account = Account.id, Banned = 1 })
	local Minutes = nil
	if Permanent then
		vRP.Update("accounts/RemoveBanned",{ Account = Account.id })
		vRP.Query("accounts/BannedPermanent",{ Account = Account.id, Reason = UseReason })
	else
		if Mode == "Horas" then
			Minutes = parseInt(Amount) * 60
		elseif Mode == "Dias" then
			Minutes = parseInt(Amount) * 1440
		else
			Minutes = parseInt(Amount)
		end
		vRP.Update("accounts/RemoveBanned",{ Account = Account.id })
		vRP.Query("accounts/InsertBanned",{ Account = Account.id, Amount = Minutes, Reason = UseReason })
	end
	SendToDiscord(Passport,(Permanent and "Permanente" or "Minutos"),(Minutes or Amount),UseReason,Account.Discord)

	local source = vRP.Source(Passport)
	if source then
		if Characters[source] then
			Characters[source].Banned = Permanent and -1 or Minutes
			Characters[source].Reason = UseReason
			Characters[source].BannedTime = os.time()
			local x,y,z = table.unpack(GetEntityCoords(GetPlayerPed(source)))
			Characters[source].BannedPos = vec3(x,y,z)
		end
		
		Player(source).state:set("Banned",true,true)
		exports.vrp:Bucket(source,"Enter",Banned.Route)
		if Banned.Mute then
			TriggerClientEvent("pma-voice:Mute",source,true)
		end

		for Permission in pairs(vRP.UserGroups(Passport)) do
			if vRP.HasService(Passport,Permission) then
				vRP.ServiceLeave(source,Passport,Permission,true)
			end
		end

		local TimeText = Permanent and "Permanente" or (parseInt(Minutes).." minutos")
		TriggerClientEvent("Notify",source,ServerName,"Você foi punido "..TimeText.." de reclusão.","server",10000)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- REMOVEBANNED
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.RemoveBanned(Passport)
  local Account = vRP.AccountOptimize(Passport)
  if not Account then
    return
  end

  vRP.Update("accounts/RemoveBanned",{ Account = Account.id })
  vRP.Update("hwid/All",{ Account = Account.id, Banned = 0 })

  local source = vRP.Source(Passport)
  if source then
    Player(source).state:set("Banned",false,true)
    if Characters[source] then
      Characters[source].Banned = 0
      Characters[source].Reason = nil
      Characters[source].BannedPos = nil
    end
    exports.vrp:Bucket(source,"Exit")
    if Banned.Mute then
      TriggerClientEvent("pma-voice:Mute",source,false)
    end
    local Pos = Banned.Leave
    vRP.Teleport(source,Pos.x,Pos.y,Pos.z)
  end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATEBANNED
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.UpdateBanned(Passport,Amount)
  local Account = vRP.AccountOptimize(Passport)
  if not Account or Account.Banned == -1 then return end

  local source = vRP.Source(Passport)
  local Current = 0
  local BannedTime = nil
  local Character = source and Characters[source] or nil
  local CurrentTime = os.time()

  if Character and type(Character.Banned) == "number" then
    if Character.Banned == -1 then
      return
    elseif Character.Banned > 0 then
      Current = parseInt(Character.Banned)
      BannedTime = Character.BannedTime
    end
  end

  if Current <= 0 then
    Current = parseInt(Account.Banned or 0)
    if Current > 0 then
      if Character then
        if not Character.BannedTime then
          Character.BannedTime = CurrentTime
        end
        Character.Banned = Current
        BannedTime = Character.BannedTime
      else
        BannedTime = CurrentTime
      end
    end
  end

  if not BannedTime then
    BannedTime = CurrentTime
    if Character then
      Character.BannedTime = BannedTime
    end
  end

  local ElapsedMinutes = math.floor((CurrentTime - BannedTime) / 60)
  local Updated = false

  if ElapsedMinutes > 0 then
    vRP.Update("accounts/ReduceBanned",{ Account = Account.id, Amount = ElapsedMinutes })
    Current = math.max(0, Current - ElapsedMinutes)
    Updated = true

    if Character then
      Character.Banned = Current
      Character.BannedTime = CurrentTime
    end
  end

  if Current <= 0 then
    if source then
      Player(source).state:set("Banned",false,true)
      if Character then
        Character.Banned = 0
        Character.Reason = nil
        Character.BannedTime = nil
      end

      vRP.Update("accounts/RemoveBanned",{ Account = Account.id })
      vRP.Update("hwid/All",{ Account = Account.id, Banned = 0 })
      exports.vrp:Bucket(source,"Exit")

      if Banned.Mute then
        TriggerClientEvent("pma-voice:Mute",source,false)
      end

      SetTimeout(1000,function()
        vRP.Teleport(source,Banned.Leave.x,Banned.Leave.y,Banned.Leave.z)
      end)
    end
    return
  end

  if Amount then
    local Reduce = parseInt(Amount)
    Current = math.max(0, Current - Reduce)
    Updated = true

    vRP.Update("accounts/ReduceBanned",{ Account = Account.id, Amount = Reduce })

    if Character then
      Character.Banned = Current
      Character.BannedTime = CurrentTime
    end
  end

  if source then
    Player(source).state:set("Banned",Current > 0,true)

    if Updated and Current > 0 then
      TriggerClientEvent("Notify",source,ServerName,"Restam "..parseInt(Current).." minutos de reclusão.","server",5000)
    end
  end

  if Character then
    Character.Banned = Current
  end
end
