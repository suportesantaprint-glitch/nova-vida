-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRPC = Tunnel.getInterface("vRP")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Lil = {}
Tunnel.bindInterface("races",Lil)
vCLIENT = Tunnel.getInterface("races")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Active = {}
local Players = {}
local Cooldown = {}
local Paymented = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADINIT
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
  for Selected in pairs(Routes) do
    Players[Selected] = {}
    Paymented[Selected] = 0

    GlobalState["Races:"..Selected] = false
  end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- INFORMATION
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Information()
  local source = source
  local Passport = vRP.Passport(source)
  if not Passport then return false end

  local Experience = { Xp = vRP.GetExperience(Passport,"Race"), Levels = TableLevel() }

  return Experience
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GLOBALSTATE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.GlobalState(Selected)
	if Routes[Selected] and not GlobalState["Races:"..Selected] then
		TriggerClientEvent("races:Start",-1,Selected)
		GlobalState["Races:"..Selected] = true
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- RUNNERS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Runners(Selected)
	Paymented[Selected] = Paymented[Selected] or 0
	if Paymented[Selected] < #Routes[Selected].Positions then
		return true
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- FINISH
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Finish(Selected,Points,Vehicle)
	local source = source
	local Passport = vRP.Passport(source)
	if not (Passport and Routes[Selected]) then
		return false
	end

	if Active[Passport] then
		Active[Passport] = nil

		if Paymented[Selected] and Paymented[Selected] > 0 then
			Paymented[Selected] = math.max(0,Paymented[Selected] - 1)

			if Paymented[Selected] == 0 and GlobalState["Races:"..Selected] then
				GlobalState["Races:"..Selected] = false
			end
		end

		local GainExperience = 8
		local Experience,Level = vRP.GetExperience(Passport,"Race")
		local MinCalculate = math.floor(Routes[Selected].Payment * 0.75)
		local MaxCalculate = math.floor(Routes[Selected].Payment * 1.25)
		local Amount = math.random(MinCalculate,MaxCalculate)

		local Positions = {}
		for Passport,v in pairs(Players[Selected]) do
			table.insert(Positions,{ Passport = Passports, Name = v.Name, Distance = v.Distance, Checkpoint = v.Checkpoint })
		end

		table.sort(Positions,function(a,b)
			if a.Checkpoint == b.Checkpoint then
				return a.Distance < b.Distance
			else
				return a.Checkpoint > b.Checkpoint
			end
		end)

		local CurrentPosition = 1
		for Line,Entry in ipairs(Positions) do
			if Entry.Passport == Passport then
				CurrentPosition = Line
				break
			end
		end
		
		local Count = #Positions
		local Default = 1.0 
		
		if Count == 1 then
			Default = Multipliers.Solo[CurrentPosition] or 0.75
		elseif Count == 2 then
			Default = Multipliers.Duo[CurrentPosition] or 0.50
		elseif Count >= 3 then
			Default = Multipliers.Full[CurrentPosition] or 0.30
		end

		if not Default then
			Default = 0.10
		end
		
		local Valuation = Amount * Default
		
		if exports.inventory:Buffs("Dexterity",Passport) then
			Valuation = Valuation + (Valuation * 0.1)
		end

		for Permission,Multiplier in pairs({ Ouro = 0.1, Prata = 0.075, Bronze = 0.05 }) do
			if vRP.HasService(Passport,Permission) then
				Valuation = Valuation + (Valuation * Multiplier)
				GainExperience = GainExperience + 2
			end
		end

		Valuation = math.floor(Valuation)
		
		if Valuation < 1 then
			Valuation = 1
		end

		vRP.UpgradeStress(Passport,10)
		exports.markers:Exit(source,Passport)
		vRP.BattlepassPoints(Passport,GainExperience)
		vRP.PutExperience(Passport,"Race",GainExperience)
		vRP.GenerateItem(Passport,ExchangeItem,Valuation,true)

		TriggerClientEvent("Notify",source,"Corridas","Você finalizou a corrida.","verde",5000)
  
		local Consult = exports.oxmysql:single_async("SELECT * FROM races WHERE Race = ? AND Mode = ? AND Passport = ?",{ Selected,0,Passport })
		if Consult then
		if Points < Consult.Points then
			exports.oxmysql:query_async("UPDATE races SET Points = ?, Vehicle = ? WHERE Race = ? AND Mode = ? AND Passport = ?",{ Points,Vehicle,Selected,0,Passport })
		end
	else
		exports.oxmysql:insert_async("INSERT INTO races (Mode,Race,Passport,Vehicle,Points) VALUES (?,?,?,?,?)",{ 0,Selected,Passport,Vehicle,Points })
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- RANKING
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Ranking(Route,Time,Mode)
	local Consult = exports.oxmysql:query_async("SELECT * FROM races WHERE Race = ? AND Mode = ? ORDER BY Points ASC LIMIT ?",{ Route,0,RankingTablet })
	local Ranking = { Runners = {} }
	if #Consult > 0 then
		for k,v in ipairs(Consult) do
			table.insert(Ranking.Runners, { Name = vRP.FullName(v["Passport"]), Time = tonumber(Dotted(v["Points"])), Vehicle = exports.vrp:VehicleName(v["Vehicle"]) })
			if k == 1 then
				Ranking.Current = { Name = vRP.FullName(v["Passport"]), Position = v["Race"], Time = tonumber(Dotted(v["Points"])), Vehicle = exports.vrp:VehicleName(v["Vehicle"]) }
			end
		end
	end
	if not Mode then
		return Ranking
	else
		return Ranking.Runners
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATEPOSITION
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.UpdatePosition(Selected,Checkpoint,Distance)
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport or not Players then return false end

	Players[Selected] = Players[Selected] or {}
	if not Players[Selected][Passport] then
		Players[Selected][Passport] = { Name = vRP.FullName(Passport), Distance = Distance, Checkpoint = Checkpoint }
	else
		Players[Selected][Passport].Distance = Distance
		Players[Selected][Passport].Checkpoint = Checkpoint
	end

	local Positions = {}
	for Passports,v in pairs(Players[Selected]) do
		table.insert(Positions,{ Passport = Passports, Name = v.Name, Distance = v.Distance, Checkpoint = v.Checkpoint })
	end

	table.sort(Positions,function(a,b)
		if a.Checkpoint == b.Checkpoint then
			return a.Distance < b.Distance
		else
			return a.Checkpoint > b.Checkpoint
		end
	end)

	local CurrentPosition = 1
	for Line,Entry in pairs(Positions) do
		if Entry.Passport == Passport then
			CurrentPosition = Line
			break
		end
	end

  TriggerClientEvent("races:Update",source,CurrentPosition,Positions)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- START
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Start(Selected)
	local Return = false
	local source = source
	local Passport = vRP.Passport(source)
	if not (Passport and Routes[Selected]) then
		return false
	end

	if GlobalState["Races:"..Selected] then
		TriggerClientEvent("races:Notify",source,"Atenção","Circuito em andamento.","amarelo")
		return false
	end

	local CooldownTime = Cooldown[Passport] and Cooldown[Passport][Selected]
	if CooldownTime and CooldownTime >= os.time() then	
		TriggerClientEvent("races:Notify",source,"Atenção","Aguarde "..CompleteTimers(CooldownTime - os.time())..".","amarelo")
		return false
	end

	if not vRP.RemoveCharges(Passport,RaceItem) then
		TriggerClientEvent("races:Notify",source,"Atenção","Precisa de <b>1x "..exports.vrp:ItemName(RaceItem).."</b>.","amarelo")
		return false
	end

	Cooldown[Passport] = Cooldown[Passport] or {}
	Cooldown[Passport][Selected] = os.time() + CooldownRaces

	Players[Selected] = Players[Selected] or {}

	exports.markers:Enter(source,"Corredor")
	Paymented[Selected] = (Paymented[Selected] or 0) + 1
	Active[Passport] = { Selected = Selected }

	for _,Sources in pairs(vRP.NumPermission("Policia")) do
		async(function()
			vRPC.PlaySound(Sources,"ATM_WINDOW","HUD_FRONTEND_DEFAULT_SOUNDSET")
			TriggerClientEvent("races:Notify",Sources,"Circuitos","Encontramos um veículo participando de uma corrida clandestina e todos os policiais foram avisados.","policia")
		end)
	end

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CANCEL
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Cancel()
	local source = source
	local Passport = vRP.Passport(source)
	if not (Passport and Active[Passport]) then
		return false
	end

	exports.markers:Exit(source,Passport)

	local Selected = Active[Passport].Selected
	if not Players[Selected][Passport] then
		return false
	end

	Players[Selected][Passport] = nil

	if Paymented[Selected] < 1 then
		return false
	end

	Paymented[Selected] = Paymented[Selected] - 1
	if Paymented[Selected] > 0 then
		return false
	end

	Paymented[Selected] = 0
	if Routes[Selected] and GlobalState["Races:"..Selected] then
		GlobalState["Races:"..Selected] = false
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- RANKINGGLOBAL
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.RankingGlobal()
  local Ranking = {}

  local Query = exports.oxmysql:query_async("SELECT * FROM races ORDER BY Race ASC, Points DESC")

  if not Query or #Query == 0 then
    return {}
  end

  for _, v in ipairs(Query) do
    local Race = v.Race
    Ranking[Race] = Ranking[Race] or {}
    Ranking[Race][#Ranking[Race] + 1] = { Passport = v.Passport, Name = vRP.FullName(v.Passport), Points = v.Points }
  end

  return Ranking
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- VEHICLESHOP
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Market()
  local source = source
  local Passport = vRP.Passport(source)
  if not Passport then return false end

  local Vehicles = {}
  for k,v in pairs(exports.vrp:VehicleList()) do
    local Class = exports.vrp:VehicleClass(k)
    if Class == "Races" then
      Vehicles[k] = { Stock = v.Stock, Price = v.Price }
    end
  end

  return { Platinums = vRP.ItemAmount(Passport,ExchangeItem), Vehicles = Vehicles }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- RENTALVEHICLE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.RentalVehicle(Model)
  local source = source
  local Passport = vRP.Passport(source)
  if not Passport then return false end

  if vRP.SelectVehicle(Passport,Model) then
    return TriggerClientEvent("races:Notify",source,"Aviso","Já possui um <b>"..exports.vrp:VehicleName(Model).."</b>.","amarelo")
  end

  local StockVehicle = exports.vrp:VehicleStock(Model)
  if StockVehicle and vRP.Scalar("vehicles/Count",{ Vehicle = Model }) >= StockVehicle then
    return TriggerClientEvent("races:Notify",source,"Aviso","Estoque insuficiente.","amarelo")
  end

  local VehiclePrice = exports.vrp:VehicleGemstone(Model)
  if VehiclePrice and vRP.TakeItem(Passport,"platinum",VehiclePrice) then
    vRP.Query("vehicles/rentalVehicles",{ Passport = Passport, Vehicle = Model, Plate = vRP.GeneratePlate(), Days = 30, Weight = exports.vrp:VehicleWeight(Model), Work = 0 })
    TriggerClientEvent("races:Notify",source,"Sucesso","Aluguel do veículo <b>"..exports.vrp:VehicleName(Model).."</b> concluído.","verde")
    Active[Passport] = nil

    return true
  end

  TriggerClientEvent("races:Notify",source,"Aviso","Platina insuficiente.","amarelo")

  return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport)
	if not Active[Passport] then
		return false
	end

	local Mode = Active[Passport].Mode
	local Selected = Active[Passport].Selected
	if not Players[Selected] or not Players[Selected][Passport] then
		return false
	end

	Players[Selected][Passport] = nil

	if Paymented[Selected] and Paymented[Selected] > 0 then
		Paymented[Selected] = math.max(0,Paymented[Selected] - 1)

		if Paymented[Selected] == 0 and Routes and GlobalState["Races:"..Selected] then
			GlobalState["Races:"..Selected] = false
		end
	end
end)