-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Lil = {}
Tunnel.bindInterface("fuelstations",Lil)
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Active = {}
local Division = {}
local Permissions = {}
local ActiveShipments = {}
local PlayerShipments = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- HASPERMISSION
-----------------------------------------------------------------------------------------------------------------------------------------
function HasPermission(Level,Permission)
	if not Permission or Permission == -1 then
		return false
	end

	if Permission == 0 then
		return true
	end

	return Level and Level <= Permission
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SUMUPGRADE
-----------------------------------------------------------------------------------------------------------------------------------------
function SumUpgrade(List,Level)
	if not List or not Level or Level <= 0 then
		return 0
	end

	local Total = 0
	for Index = 1, Level do
		if List[Index] and List[Index].Amount then
			Total = Total + List[Index].Amount
		end
	end

	return Total
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- FUELSTATION:OPEN
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("fuelstations:Open")
AddEventHandler("fuelstations:Open",function(Permission)
    local source = source
    local Passport = vRP.Passport(source)

    if not Passport or not Permission or not Locations[Permission] then
        return false
    end

    local Level = vRP.HasPermission(Passport, Permission)
    local Consult = exports.oxmysql:single_async("SELECT * FROM fuelstations_creative WHERE Permission = ?", { Permission })

    if not Consult then
        local Location = Locations[Permission]
        local Price = Location.Price or 0

        if Price <= 0 then
            TriggerClientEvent("fuelstations:Notify",source,"Central","Este posto não está disponível para compra.","amarelo")
            return
        end

        if not vRP.Request(source,"Posto de Combustível",string.format("Comprar estabelecimento por <b>$%s</b>?",Dotted(Price))) then
            return
        end

        if not vRP.PaymentFull(Passport, Price, true) then
            TriggerClientEvent("fuelstations:Notify",source,"Central","Dinheiro insuficiente.","amarelo")
            return
        end

        exports.oxmysql:insert_async("INSERT INTO fuelstations_creative (Permission,Name,Color,Blip,Stock,FuelPrice,Empty,MoneyEarned,MoneySpent,FuelImported,Visits) VALUES (?,?,?,?,?,?,?,?,?,?,?)",{ Permission, Config.DefaulName, Config.DefaultColor, Config.DefaultIcon, 0, Config.DefaultPricePerLiter, 0, 0, 0, 0, 0 })
        
        local Datatable = vRP.GetSrvData("FuelStations:"..Permission,true)
        Datatable.Upgrades = { Stock = 0, Truck = 0, Relationship = 0 }
        Datatable.Historical = {}
        vRP.SetSrvData("FuelStations:"..Permission,Datatable,true)
        vRP.SetPermission(Passport,Permission,1)
        
        Division[Passport] = Permission
        Permissions[Passport] = Config.OtherPermissions[Permission] or Config.Permissions
        TriggerClientEvent("fuelstations:Opened",source)
        TriggerClientEvent("fuelstations:Blip",-1,Permission,Config.DefaulName,Config.DefaultColor,Config.DefaultIcon)
        TriggerClientEvent("fuelstations:Notify",source,"Central","Você agora é o proprietário deste posto.","verde")
        return
    end

    if Level then
        Division[Passport] = Permission
        Permissions[Passport] = Config.OtherPermissions[Permission] or Config.Permissions
        TriggerClientEvent("fuelstations:Opened",source)
    else
        local ConsultJobs = exports.oxmysql:query_async("SELECT COUNT(*) as Count FROM fuelstations_creative_jobs WHERE Permission = @Permission",{ Permission = Permission })
        if (ConsultJobs and ConsultJobs[1] and ConsultJobs[1].Count or 0) <= 0 then
            TriggerClientEvent("Notify",source,"Aviso","Não há vagas disponíveis neste posto.","amarelo",5000)
            return
        end

        Division[Passport] = Permission
        TriggerClientEvent("fuelstations:Jobs",source)
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- FUELSTATION:GALLON
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("fuelstations:Gallon")
AddEventHandler("fuelstations:Gallon", function(Departmenty)
	local source = source
	local Passport = vRP.Passport(source)
	
	if not Passport or not Departmenty or not Locations[Departmenty] then
		return
	end

	local Consult = exports.oxmysql:single_async("SELECT * FROM fuelstations_creative WHERE Permission = ?",{ Departmenty })
	if not Consult then
		return
	end

	if Consult.Stock < Config.StockGallon then
		TriggerClientEvent("Notify", source, "Central", "Estoque insuficiente para vender galão.", "amarelo")
		return
	end

	if vRP.MaxItens(Passport,Config.ItemGallon,1) then
		TriggerClientEvent("Notify",source,"Central","Você já possui este item.","amarelo")
		return
	end

	if not vRP.CheckWeight(Passport,Config.ItemGallon, 1) or not vRP.CheckWeight(Passport,Config.ItemGallonFuel,Config.GallonFuelAmount) then
		TriggerClientEvent("Notify",source,"Central","Verifique o peso da mochila.","amarelo")
		return
	end

	if not vRP.PaymentFull(Passport,Config.PriceGallon,true) then
		TriggerClientEvent("Notify",source,"Central","Dinheiro insuficiente.","amarelo")
		return
	end

	vRP.GenerateItem(Passport,Config.ItemGallon,1,true)
	vRP.GenerateItem(Passport,Config.ItemGallonFuel,Config.GallonFuelAmount,true)

	exports.oxmysql:update_async("UPDATE fuelstations_creative SET Stock = GREATEST(Stock - ?,0) WHERE Permission = ?",{ Config.StockGallon, Departmenty })

    vRP.PermissionsUpdate(Departmenty,"Bank","+",Config.PriceGallon)

    local Datatable = vRP.GetSrvData("FuelStations:"..Departmenty,true)
    table.insert(Datatable.Historical, { Type = "Fuel", Player = { Passport = Passport, Name = vRP.FullName(Passport) }, Value = Config.PriceGallon, Amount = Config.StockGallon })
	vRP.SetSrvData("FuelStations:"..Departmenty,Datatable,true)

	TriggerClientEvent("Notify",source,"Central","Galão adquirido com sucesso.","verde")
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Player()
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

	if not Passport or not Departmenty then
		return false
	end

	local Level = vRP.HasPermission(Passport,Departmenty)

	return {
		MaxGroup = vRP.Permissions(Departmenty, "Members"),
		Player = {
			Passport = Passport,
			Name = vRP.FullName(Passport),
			Level = Level
		},
		Permissions = {
            Stock = {
				View = HasPermission(Level,Permissions[Passport].Stock.View),
				Edit = HasPermission(Level,Permissions[Passport].Stock.Edit)
			},
			Replenishment = {
				View = HasPermission(Level,Permissions[Passport].Replenishment.View),
				Import = HasPermission(Level,Permissions[Passport].Replenishment.Import),
				Export = HasPermission(Level,Permissions[Passport].Replenishment.Export)
			},
			OfferJobs = {
				View = HasPermission(Level,Permissions[Passport].OfferJobs.View),
				Create = HasPermission(Level,Permissions[Passport].OfferJobs.Create),
				Edit = HasPermission(Level,Permissions[Passport].OfferJobs.Edit),
				Destroy = HasPermission(Level,Permissions[Passport].OfferJobs.Destroy)
			},
			Bank = {
				View = HasPermission(Level,Permissions[Passport].Bank.View),
				Deposit = HasPermission(Level,Permissions[Passport].Bank.Deposit),
				Withdraw = HasPermission(Level,Permissions[Passport].Bank.Withdraw),
				Transfer = HasPermission(Level,Permissions[Passport].Bank.Transfer)
			},
			Update = HasPermission(Level,Permissions[Passport].Update),
			Upgrades = HasPermission(Level,Permissions[Passport].Upgrades),
			Employees = {
				View = HasPermission(Level,Permissions[Passport].Employees.View),
				Create = HasPermission(Level,Permissions[Passport].Employees.Create),
				Edit = HasPermission(Level,Permissions[Passport].Employees.Edit),
				Dismiss = HasPermission(Level,Permissions[Passport].Employees.Dismiss)
			}
		},
		Hierarchy = vRP.Hierarchy(Departmenty)
	}
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- HOME
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Home()
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

	if not Passport or not Departmenty then
		return false
	end

	local Consult = exports.oxmysql:single_async("SELECT * FROM fuelstations_creative WHERE Permission = ?",{ Departmenty })
    local Datatable = vRP.GetSrvData("FuelStations:"..Departmenty, true)

	return { Name = Consult.Name, Color = Consult.Color, Icon = Consult.Blip, Statistics = { MoneyEarned = Consult.MoneyEarned, MoneySpent = Consult.MoneySpent, FuelImported = Consult.FuelImported, Visits = Consult.Visits }, Stock = Consult.Stock, MaxStock = Config.DefaultMaxStock + SumUpgrade(Config.Upgrades.Stock,Datatable.Upgrades.Stock) }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Update(Data)
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

	if not Passport or not Departmenty then
		return false
	end

	local Level = vRP.HasPermission(Passport,Departmenty)
	if not HasPermission(Level,Permissions[Passport].Update) then
		return false
	end

	exports.oxmysql:update_async("UPDATE fuelstations_creative SET Name = ?, Color = ?, Blip = ? WHERE Permission = ?",{ Data.Name,Data.Color,Data.Icon,Departmenty })
	TriggerClientEvent("fuelstations:Notify",source,"Sucesso","Informações atualizadas.","verde")
	TriggerClientEvent("fuelstations:Blip",-1,Departmenty,Data.Name,Data.Color,Data.Icon)

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- STOCK
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Stock()
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

	if not Passport or not Departmenty then
		return false
	end

	local Level = vRP.HasPermission(Passport,Departmenty)
	if not HasPermission(Level,Permissions[Passport].Stock.View) then
		return false
	end

	local Consult = exports.oxmysql:single_async("SELECT * FROM fuelstations_creative WHERE Permission = ?",{ Departmenty })
    local Datatable = vRP.GetSrvData("FuelStations:"..Departmenty, true)

	return { Price = Consult.FuelPrice, MinPrice = Config.MinPricePerLiter, MaxPrice = Config.MaxPricePerLiter, Stock = Consult.Stock, MaxStock = Config.DefaultMaxStock + SumUpgrade(Config.Upgrades.Stock,Datatable.Upgrades.Stock) }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- FUELSTOCK
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.FuelStock(Permission)
    local Consult = exports.oxmysql:single_async("SELECT * FROM fuelstations_creative WHERE Permission = ?", { Permission})
    if not Consult then
    	return { Stock = 999999, FuelPrice = Config.DefaultPricePerLiter, Name = Locations[Permission] and Locations[Permission].Name or Config.DefaulName }
    end

    return { Stock = Consult.Stock or 0, FuelPrice = Consult.FuelPrice or Config.DefaultPricePerLiter, Name = Consult.Name or Config.DefaulName }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATESTOCK
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.UpdateStock(Price)
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

	if not Passport or not Departmenty or Price > Config.MaxPricePerLiter or Price < Config.MinPricePerLiter then
		return false
	end

	local Level = vRP.HasPermission(Passport,Departmenty)
	if not HasPermission(Level,Permissions[Passport].Stock.Edit) then
		return false
	end

	exports.oxmysql:update_async("UPDATE fuelstations_creative SET FuelPrice = ? WHERE Permission = ?",{ Price,Departmenty })
	TriggerClientEvent("fuelstation:Notify",source,"Sucesso","Preço por litro atualizado.","verde")

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- BANK
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Bank()
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

	local Level = vRP.HasPermission(Passport,Departmenty)
	if not HasPermission(Level,Permissions[Passport].Bank.View) then
		return false
	end

  	local Consult = exports.oxmysql:query_async("SELECT * FROM painel_creative_transactions WHERE Permission = @Permission LIMIT 50", { Permission = Departmenty })

  	local Transactions = {}
  	for _, v in ipairs(Consult) do
    	table.insert(Transactions,{ Player = { Passport = v.Passport, Name = vRP.FullName(v.Passport) }, To = { Passport = v.Transfer,Name = vRP.FullName(v.Transfer) }, Type = v.Type, Value = v.Value, Date = v.Timestamp, Amount = v.Amount })
  	end

	return { Balance = vRP.Permissions(Departmenty,"Bank"), Historical = Transactions }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DEPOSITBANK
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.DepositBank(Value)
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

	if not Passport or not Departmenty then
		return false
	end

	local Level = vRP.HasPermission(Passport,Departmenty)
	if not HasPermission(Level,Permissions[Passport].Bank.Deposit) then
		return false
	end

	if vRP.PaymentBank(Passport,Value) then
		exports.oxmysql:insert_async("INSERT INTO painel_creative_transactions (Type,Passport,Value,Timestamp,Permission) VALUES (@Type,@Passport,@Value,@Timestamp,@Permission)",{ Type = "Deposit", Passport = Passport, Value = Value, Timestamp = os.time(), Permission = Departmenty })
		TriggerClientEvent("fuelstations:Notify",source,"Sucesso","Deposito realizado.","verde")
		vRP.PermissionsUpdate(Departmenty,"Bank","+",Value)
		return true
	end


	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- WITHDRAWBANK
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.WithdrawBank(Value)
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

	if not Passport or not Departmenty then
		return false
	end

	local Level = vRP.HasPermission(Passport,Departmenty)
	if not HasPermission(Level,Permissions[Passport].Bank.Withdraw) then
		return false
	end


	if vRP.Permissions(Departmenty,"Bank") >= Value then
		exports.oxmysql:insert_async("INSERT INTO painel_creative_transactions (Type,Passport,Value,Timestamp,Permission) VALUES (@Type,@Passport,@Value,@Timestamp,@Permission)",{ Type = "Withdraw", Passport = Passport, Value = Value, Timestamp = os.time(), Permission = Departmenty })
		TriggerClientEvent("fuelstations:Notify",source,"Sucesso","Saque realizado.","verde")
		vRP.GiveBank(Passport,Value * Config.BankTaxWithdraw)
		vRP.PermissionsUpdate(Departmenty,"Bank","-",Value)
		return true
	end


	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TRANSFERBANK
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.TransferBank(OtherPassport,Value)
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

	if not Passport or not Departmenty then
		return false
	end

	local Level = vRP.HasPermission(Passport,Departmenty)
	if not HasPermission(Level,Permissions[Passport].Bank.Transfer) then
		return false
	end


	local Identity = vRP.Identity(OtherPassport)
	if Identity and vRP.Permissions(Departmenty,"Bank") >= Value then
		exports.oxmysql:insert_async("INSERT INTO painel_creative_transactions (Type,Passport,Value,Timestamp,Transfer,Permission) VALUES (@Type,@Passport,@Value,@Timestamp,@Transfer,@Permission)",{ Type = "Transfer", Passport = Passport, Value = Value, Timestamp = os.time(), Transfer = OtherPassport, Permission = Departmenty })
		TriggerClientEvent("fuelstations:Notify",source,"Sucesso","Transferência realizada.","verde")
		vRP.GiveBank(OtherPassport,Value * Config.BankTaxTransfer,true)
		vRP.PermissionsUpdate(Departmenty,"Bank","-",Value)

		return { Passport = OtherPassport, Name = vRP.FullName(Passport) }
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- REPLENISHMENT
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Replenishment()
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]
	
	if not Passport or not Departmenty then return false end
	
	local Active = ActiveShipments[Departmenty]
	local Payload = Active and { Index = Active.Index, Mode = Active.Mode } or false
	
	return Payload
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- STARTSHIPMENT
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.StartShipment(Index,Mode)
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

	if not Passport or not Departmenty then
		return false
	end

	local ShipmentData = Config.Replenishments[Index]
	if not ShipmentData then
		return false
	end
	
	local Level = vRP.HasPermission(Passport,Departmenty)
	if not HasPermission(Level,Permissions[Passport].Replenishment[Mode]) then
		return false
	end
	
	if ActiveShipments[Departmenty] then
		TriggerClientEvent("fuelstations:Notify",source,"Central","Já existe uma carga ativa para este posto.","amarelo")
		return false
	end
	
	if Mode == "Import" then
		local Balance = vRP.Permissions(Departmenty,"Bank")
		
		if Balance < ShipmentData.Import then
			TriggerClientEvent("fuelstations:Notify",source,"Central","Saldo insuficiente no banco do posto.","amarelo")
			return false
		end
	end
		
	local Location = Locations[Departmenty]
	local Destination = Location.Packages[ShipmentData.Package]
	local Routes = { Destination, Location.Delivery }
	
	local Datatable = vRP.GetSrvData("FuelStations:"..Departmenty,true)
	local TruckBonus = SumUpgrade(Config.Upgrades.Truck,Datatable.Upgrades.Truck)
	local RelationshipBonus = SumUpgrade(Config.Upgrades.Relationship,Datatable.Upgrades.Relationship)
	local Amount = math.floor(ShipmentData.Amount + (ShipmentData.Amount * (TruckBonus / 100)))
	local Factor = Amount / ShipmentData.Amount
	
	local MaxStock = Config.DefaultMaxStock + SumUpgrade(Config.Upgrades.Stock,Datatable.Upgrades.Stock)
	local Consult = exports.oxmysql:single_async("SELECT * FROM fuelstations_creative WHERE Permission = ?",{ Departmenty })
		
	if Mode == "Import" and (Consult.Stock + Amount) > MaxStock then
		TriggerClientEvent("fuelstations:Notify",source,"Central","Organize o estoque antes de importar esta carga.","amarelo")
		return false
	end
		
	if Mode == "Export" and Consult.Stock < Amount then
		TriggerClientEvent("fuelstations:Notify",source,"Central","Combustível insuficiente para exportar.","amarelo")
		return false
	end
		
	ActiveShipments[Departmenty] = { Passport = Passport, Index = Index, Mode = Mode, Amount = Amount, ImportCost = math.floor(ShipmentData.Import * Factor * (1 - (RelationshipBonus / 100))), ExportValue = math.floor(ShipmentData.Export * Factor) }
		
	PlayerShipments[Passport] = Departmenty 
		
	TriggerClientEvent("fuelstations:Init",source,Routes)
	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- FINISHSHIPMENT
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.FinishShipment()
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = PlayerShipments[Passport] or Division[Passport]
	local Job = ActiveShipments[Departmenty]
		
	if not Passport or not Departmenty or not Job then
		return false
	end

	if Job.Passport ~= Passport then
		return false
	end
		
	ActiveShipments[Departmenty] = nil
		
	PlayerShipments[Passport] = nil
		
	TriggerClientEvent("fuelstations:Finish",source)
	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- JOBS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Jobs()
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

	if not Passport or not Departmenty then
		return false
	end
	

	local Consult = exports.oxmysql:single_async("SELECT Name FROM fuelstations_creative WHERE Permission = @Permission",{ Permission = Departmenty })
	local JobsList = exports.oxmysql:query_async("SELECT * FROM fuelstations_creative_jobs WHERE Permission = @Permission",{ Permission = Departmenty })
	local Jobs = {}
	for _,v in ipairs(JobsList or {}) do
		Jobs[#Jobs + 1] = { Id = v.id,Name = v.Name,Amount = v.Amount,Reward = v.Reward }
	end

	return { Active = Active[Passport] and Active[Passport].Id, Name = Consult and Consult.Name or Config.DefaultName, Jobs = Jobs }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- STARTJOB
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.StartJob(Id)
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

	if not Passport or not Departmenty or Active[Passport] then return false end

	local Job = exports.oxmysql:single_async("SELECT * FROM fuelstations_creative_jobs WHERE id = @Id AND Permission = @Permission",{ Id = Id,Permission = Departmenty })
	if not Job or not exports.oxmysql:single_async("SELECT * FROM fuelstations_creative WHERE Permission = @Permission",{ Permission = Departmenty }) then return false end
	if vRP.Permissions(Departmenty,"Bank") < Job.Reward then
		TriggerClientEvent("fuelstations:Notify",source,"Aviso","Dinheiro insuficiente.","amarelo")
		return false
	end

	Active[Passport] = { Id = Job.id,Permission = Departmenty,Name = Job.Name,Amount = Job.Amount,Reward = Job.Reward }
	local Location = Locations[Departmenty]
	if Location and Location.Delivery and Location.Packages then
		local PackageType = Job.Amount >= 500 and "Large" or Job.Amount >= 250 and "Medium" or "Small"
		local PackageLocation = Location.Packages[PackageType] or Location.Packages.Small
		TriggerClientEvent("fuelstations:Init",source,{ PackageLocation,Location.Delivery })
	end

	TriggerClientEvent("fuelstations:Notify",source,"Sucesso","Serviço iniciado. Dirija-se ao local de coleta.","verde")

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- FINISHJOB
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.FinishJob()
	local source = source
	local Passport = vRP.Passport(source)

	if not Passport or not Active[Passport] then return false end

	TriggerClientEvent("fuelstations:Notify",source,"Aviso","Você precisa completar a entrega para finalizar o serviço.","amarelo")

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- OFFERJOBS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.OfferJobs()
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

	if not Passport or not Departmenty then
		return false
	end
	
	if not HasPermission(vRP.HasPermission(Passport,Departmenty),Permissions[Passport].OfferJobs.View) then return false end

	local JobsList = exports.oxmysql:query_async("SELECT * FROM fuelstations_creative_jobs WHERE Permission = @Permission",{ Permission = Departmenty })
	local Jobs = {}
	for _,v in ipairs(JobsList or {}) do
		Jobs[#Jobs + 1] = { Id = v.id, Name = v.Name, Amount = v.Amount, Reward = v.Reward }
	end

	return Jobs
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CREATEJOB
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.CreateJob(Data)
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

	if not Passport or not Departmenty then
		return false
	end
	
	if not HasPermission(vRP.HasPermission(Passport,Departmenty),Permissions[Passport].OfferJobs.Create) then return false end
	if not Data.Name or not Data.Amount or not Data.Reward or Data.Amount <= 0 or Data.Reward <= 0 then return false end

	if vRP.Permissions(Departmenty,"Bank") < Data.Reward then
		TriggerClientEvent("fuelstations:Notify",source,"Aviso","Dinheiro insuficiente.","amarelo")
		return false
	end

	local Result = exports.oxmysql:insert_async("INSERT INTO fuelstations_creative_jobs (Permission,Name,Amount,Reward) VALUES (@Permission,@Name,@Amount,@Reward)",{ Permission = Departmenty,Name = Data.Name,Amount = Data.Amount,Reward = Data.Reward })
	if Result then TriggerClientEvent("fuelstations:Notify",source,"Sucesso","Emprego criado com sucesso.","verde") end

	return Result or false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATEJOB
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.UpdateJob(Data)
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]
	
	if not Passport or not Departmenty then
		return false
	end

	local Level = vRP.HasPermission(Passport,Departmenty)
	if not HasPermission(Level,Permissions[Passport].OfferJobs.Edit) then
		return false
	end

	if not Data.Id or not Data.Name or not Data.Amount or not Data.Reward then
		return false
	end

	if Data.Amount <= 0 or Data.Reward <= 0 then
		return false
	end

	exports.oxmysql:update_async("UPDATE fuelstations_creative_jobs SET Name = ?, Amount = ?, Reward = ? WHERE id = ? AND Permission = ?",{ Data.Name, Data.Amount, Data.Reward, Data.Id, Departmenty })
	TriggerClientEvent("fuelstations:Notify",source,"Sucesso","Emprego atualizado com sucesso.","verde")
	
	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DESTROYJOB
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.DestroyJob(Id)
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]
	
	if not Passport or not Departmenty then
		return false
	end

	local Level = vRP.HasPermission(Passport,Departmenty)
	if not HasPermission(Level,Permissions[Passport].OfferJobs.Destroy) then
		return false
	end

	if not Id then
		return false
	end

	exports.oxmysql:query_async("DELETE FROM fuelstations_creative_jobs WHERE id = ? AND Permission = ?",{ Id, Departmenty })
	TriggerClientEvent("fuelstations:Notify",source,"Sucesso","Emprego removido com sucesso.","verde")
	
	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PAYMENT
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Payment()
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport then
		return false
	end

	local Departmenty = PlayerShipments[Passport] or Division[Passport]
	local Job = Departmenty and ActiveShipments[Departmenty]
	local Service = Active[Passport]

	if not Job and Service then
		local Consult = exports.oxmysql:single_async("SELECT * FROM fuelstations_creative WHERE Permission = @Permission",{ Permission = Service.Permission })
		if not Consult then
			Active[Passport] = nil
			TriggerClientEvent("fuelstations:Finish",source)
			return false
		end

		local Datatable = vRP.GetSrvData("FuelStations:"..Service.Permission,true)
		local Stock = parseInt(Consult.Stock) or 0
		local MaxStock = Config.DefaultMaxStock + SumUpgrade(Config.Upgrades.Stock, Datatable.Upgrades.Stock)
		local AvailableStock = math.max(MaxStock - Stock,0)

		if AvailableStock < Service.Amount then
			Active[Passport] = nil
			TriggerClientEvent("fuelstations:Notify",source,"Central","O estoque está cheio.","amarelo")
			TriggerClientEvent("fuelstations:Finish",source)
			return false
		end

		if vRP.Permissions(Service.Permission,"Bank") < Service.Reward then
			Active[Passport] = nil
			TriggerClientEvent("fuelstations:Notify",source,"Central","Saldo insuficiente no banco do posto.","amarelo")
			TriggerClientEvent("fuelstations:Finish",source)
			return false
		end

		local Delivered = math.min(Service.Amount,AvailableStock)
		exports.oxmysql:update_async("UPDATE fuelstations_creative SET Stock = LEAST(Stock + @Delivered,@MaxStock),MoneySpent = MoneySpent + @Reward,FuelImported = FuelImported + @Delivered WHERE Permission = @Permission",{ Delivered = Delivered,MaxStock = MaxStock,Reward = Service.Reward,Permission = Service.Permission })
		vRP.PermissionsUpdate(Service.Permission,"Bank","-",Service.Reward)
		vRP.GiveBank(Passport,Service.Reward,true)
		exports.oxmysql:insert_async("INSERT INTO painel_creative_transactions (Type,Passport,Value,Timestamp,Permission,Amount) VALUES (@Type,@Passport,@Value,@Timestamp,@Permission,@Amount)",{ Type = "Import", Passport = Passport, Value = Service.Reward, Timestamp = os.time(), Permission = Service.Permission, Amount = Delivered })
		exports.oxmysql:query_async("DELETE FROM fuelstations_creative_jobs WHERE id = @Id AND Permission = @Permission",{ Id = Service.Id,Permission = Service.Permission })

		table.insert(Datatable.Historical,{ Type = "Job", Player = { Passport = Passport, Name = vRP.FullName(Passport) }, Value = Service.Reward, Amount = Delivered })
		vRP.SetSrvData("FuelStations:"..Service.Permission,Datatable,true)

		Active[Passport] = nil

		local Name = Consult.Name or Config.DefaultName or Config.DefaulName
		TriggerClientEvent("Notify",source,Name,"Você importou <b>"..Delivered.."Lts</b> de combustível e recebeu <b>"..Currency.." "..Dotted(Service.Reward).."</b>.","verde",5000)
		TriggerClientEvent("fuelstations:Finish",source)
		return true
	end

	if not Departmenty or not Job then
		return false
	end

	if Job.Passport ~= Passport then
		return false
	end

	local Consult = exports.oxmysql:single_async("SELECT * FROM fuelstations_creative WHERE Permission = ?",{ Departmenty })
	if not Consult then
		return false
	end

	local Stock = parseInt(Consult.Stock) or 0
	local Delivered = Job.Amount
	local Payout = 0

	local function ProcessShipment()
		if Job.Mode == "Import" then
			local Datatable = vRP.GetSrvData("FuelStations:"..Departmenty,true)
			local MaxStock = Config.DefaultMaxStock + SumUpgrade(Config.Upgrades.Stock, Datatable.Upgrades.Stock)
			local Available = math.max(MaxStock - Stock, 0)

			if Available <= 0 then
				TriggerClientEvent("fuelstations:Notify",source,"Central","O estoque está cheio. Utilize/ou esvazie antes de importar.","amarelo")
				return false
			end
				
			Delivered = math.min(Delivered, Available)
			local UnitCost = Job.ImportCost / Job.Amount
			local Cost = math.floor(Delivered * UnitCost)

			exports.oxmysql:update_async("UPDATE fuelstations_creative SET Stock = Stock + ?, MoneySpent = MoneySpent + ?, FuelImported = FuelImported + ? WHERE Permission = ?",{ Delivered, Cost, Delivered, Departmenty })

			vRP.PermissionsUpdate(Departmenty,"Bank","-",Cost)
				
			table.insert(Datatable.Historical,{ Type = "Import", Player = { Passport = Passport, Name = vRP.FullName(Passport) }, Value = Cost, Amount = Delivered })
			vRP.SetSrvData("FuelStations:"..Departmenty,Datatable,true)

			local Valuation = math.floor(Delivered * 2)
			if Valuation > 0 then
				if exports.inventory:Buffs("Dexterity",Passport) then
					Valuation = Valuation + math.floor(Valuation * 0.1)
				end

				vRP.GenerateItem(Passport,"dollar",Valuation,true)
			end

			TriggerClientEvent("Notify",source,"Sucesso","Você importou <b>"..Delivered.."Lts</b> de combustível e recebeu <b>$"..Dotted(Valuation).."</b>.","success")

			return true

		elseif Job.Mode == "Export" then
			if Stock <= 0 then
				TriggerClientEvent("fuelstations:Notify",source,"Central","Não há combustível suficiente em estoque.","amarelo")
				return false
			end
				
			Delivered = math.min(Delivered, Stock)
			local UnitValue = Job.ExportValue / Job.Amount
			Payout = math.floor(Delivered * UnitValue)

			Consult.Stock = math.max(Stock - Delivered, 0)
			Consult.MoneyEarned = (parseInt(Consult.MoneyEarned) or 0) + Payout

			exports.oxmysql:update_async("UPDATE fuelstations_creative SET Stock = GREATEST(Stock - ?,0), MoneyEarned = MoneyEarned + ? WHERE Permission = ?",{ Delivered, Payout, Departmenty })
				
			local Datatable = vRP.GetSrvData("FuelStations:"..Departmenty,true)

			vRP.PermissionsUpdate(Departmenty,"Bank","+",Payout)
				
			table.insert(Datatable.Historical,{ Type = "Export", Player = { Passport = Passport, Name = vRP.FullName(Passport) }, Value = Payout, Amount = Delivered })
			vRP.SetSrvData("FuelStations:"..Departmenty,Datatable,true)

			local Valuation = math.floor(Delivered * 2)
			if Valuation > 0 then
				if exports.inventory:Buffs("Dexterity",Passport) then
					Valuation = Valuation + math.floor(Valuation * 0.1)
				end

				vRP.GenerateItem(Passport,"dollar",Valuation,true)
			end

			TriggerClientEvent("fuelstations:Notify",source,"Central","Você exportou <b>"..Delivered.."Lts</b> de combustível e recebeu <b>$"..Dotted(Valuation).."</b>.","verde")

			return true
		else
			return false
		end
	end
		
	local shipmentSuccess = ProcessShipment()

	if not shipmentSuccess then
		ActiveShipments[Departmenty] = nil
			
		PlayerShipments[Passport] = nil
			
		TriggerClientEvent("fuelstations:Finish",source)
		return false
	end
		
	ActiveShipments[Departmenty] = nil
		
	PlayerShipments[Passport] = nil
		
	TriggerClientEvent("fuelstations:Finish",source)
	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPGRADES
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Upgrades()
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

	if not Passport or not Departmenty then return false end

	local Level = vRP.HasPermission(Passport,Departmenty)
	if not HasPermission(Level,Permissions[Passport].Upgrades) then
		return false
	end

	local Datatable = vRP.GetSrvData("FuelStations:"..Departmenty,true)
	Datatable.Upgrades = Datatable.Upgrades or { Stock = 0, Truck = 0, Relationship = 0 }
	Datatable.Historical = Datatable.Historical or {}
	vRP.SetSrvData("FuelStations:"..Departmenty,Datatable,true)

	return {
		Stock = { Level = Datatable.Upgrades.Stock or 0, List = Config.Upgrades.Stock },
		Truck = { Level = Datatable.Upgrades.Truck or 0, List = Config.Upgrades.Truck },
		Relationship = { Level = Datatable.Upgrades.Relationship or 0, List = Config.Upgrades.Relationship }
	}
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPGRADE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Upgrade(Mode)
	local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

	if not Passport or not Departmenty then return false end

	local Level = vRP.HasPermission(Passport,Departmenty)
	if not HasPermission(Level,Permissions[Passport].Upgrades) then
		return false
	end

	if not Mode or not Config.Upgrades[Mode] then
		return false
	end

	local Datatable = vRP.GetSrvData("FuelStations:"..Departmenty,true)
	Datatable.Upgrades = Datatable.Upgrades or { Stock = 0, Truck = 0, Relationship = 0 }
	Datatable.Historical = Datatable.Historical or {}

	local CurrentLevel = Datatable.Upgrades[Mode] or 0
	local UpgradeData = Config.Upgrades[Mode][CurrentLevel + 1]

	if not UpgradeData then
		TriggerClientEvent("fuelstations:Notify",source,"Central","Todas as melhorias dessa categoria já foram adquiridas.","amarelo")
		return false
	end

	local Balance = vRP.Permissions(Departmenty,"Bank")
	if Balance < UpgradeData.Price then
		TriggerClientEvent("fuelstations:Notify",source,"Central","Saldo insuficiente no banco do posto.","amarelo")
		return false
	end

	vRP.PermissionsUpdate(Departmenty,"Bank","-",UpgradeData.Price)
	Datatable.Upgrades[Mode] = CurrentLevel + 1

	table.insert(Datatable.Historical,{ Type = "Upgrade", Player = { Passport = Passport, Name = vRP.FullName(Passport) }, Value = UpgradeData.Price, Upgrade = Mode, Level = CurrentLevel + 1 })
	vRP.SetSrvData("FuelStations:"..Departmenty,Datatable,true)

	TriggerClientEvent("fuelstations:Notify",source,"Sucesso","Melhoria aplicada com sucesso.","verde")
	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- EMPLOYEES
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Employees()
    local source = source
    local Passport = vRP.Passport(source)
    local Departmenty = Division[Passport]

    if not Passport or not Departmenty then
        return false
    end

    local Level = vRP.HasPermission(Passport,Departmenty)
    if not HasPermission(Level,Permissions[Passport].Employees.View) then
        return false
    end

    local Members = vRP.DataGroups(Departmenty) or {}
    local List = {}

    for Employee,Hierarchy in pairs(Members) do
        Employee = tonumber(Employee)
		local Calculated = CompleteTimers(vRP.Playing(Employee,Departmenty) or 0)
		local Status = (vRP.Source(Employee) and "Ativo há " or "Inativo há ") .. Calculated

        List[#List + 1] = { Passport = Employee, Name = vRP.FullName(Employee), Hierarchy = Hierarchy or 1, Status = Status }
    end

    return List
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVITEEMPLOYEE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.InviteEmployee(TargetPassport)
    local source = source
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]
	
    local Level = vRP.HasPermission(Passport,Departmenty)
	if not Departmenty or not HasPermission(Level,Permissions[Passport].Employees.Create) then
		return false
	end

	TargetPassport = tonumber(TargetPassport)
	if not TargetPassport or vRP.HasPermission(TargetPassport,Departmenty) then
		return false
	end

	if vRP.AmountGroups(Departmenty) >= vRP.Permissions(Departmenty,"Members") then
		TriggerClientEvent("fuelstations:Notify",source,"Central","Limite de membros atingido.","amarelo")
		return false
	end

	local TargetSource = vRP.Source(TargetPassport)
	if not TargetSource then
		TriggerClientEvent("fuelstations:Notify",Source,"Central","Passaporte offline.","amarelo")
		return false
	end

	if vRP.Request(TargetSource,"Postos","Você foi convidado para o posto "..Departmenty..". Deseja aceitar?") then
		vRP.SetPermission(TargetPassport,Departmenty)
		TriggerClientEvent("fuelstations:Notify",source,"Central","Funcionário adicionado.","verde")
		return true
	end

	TriggerClientEvent("fuelstations:Notify",source,"Central","Convite recusado.","amarelo")
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- HIERARCHYEMPLOYEE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.HierarchyEmployee(Data)
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]
	
    local Level = vRP.HasPermission(Passport,Departmenty)
	if not Departmenty or not HasPermission(Level,Permissions[Passport].Employees.Edit) then
		return false
	end

	local Target = tonumber(Data.Passport)
	local Mode = Data.Mode == "Promote" and "Promote" or "Demote"
	
	if not Target or Target == Passport then
		return false
	end

	local TargetLevel = vRP.HasPermission(Target,Departmenty)
	if not TargetLevel then
		return false
	end

	if Mode == "Promote" and TargetLevel <= Level + 1 then
		return false
	end

	if Mode == "Demote" and not (Level < TargetLevel and TargetLevel < #vRP.Hierarchy(Departmenty)) then
		return false
	end

	vRP.SetPermission(Target,Departmenty,nil,Mode)
	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISMISSEMPLOYEE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.DismissEmployee(TargetPassport)
	local Passport = vRP.Passport(source)
	local Departmenty = Division[Passport]

    local Level = vRP.HasPermission(Passport,Departmenty)
	if not Departmenty or not HasPermission(Level,Permissions[Passport].Employees.Dismiss) then
		return false
	end

	TargetPassport = tonumber(TargetPassport)
	if not TargetPassport or TargetPassport == Passport then
		return false
	end

	local TargetLevel = vRP.HasPermission(TargetPassport,Departmenty)
	if not TargetLevel or TargetLevel <= Level then
		return false
	end

	vRP.RemovePermission(TargetPassport,Departmenty)
	PlayerShipments[TargetPassport] = nil
	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------------------------------------------------------------------------------------
exports("UpdateStock", function(Departmenty,Amount,Mode,Value,Customer)
	local Consult = exports.oxmysql:single_async("SELECT * FROM fuelstations_creative WHERE Permission = ?",{ Departmenty })
	if not Consult or not Amount or Amount <= 0 then
		return false
	end

	if Mode == "-" and Consult.Stock < Amount then
		return false
	end

    local Datatable = vRP.GetSrvData("FuelStations:"..Departmenty,true)

	if Mode == "-" then
		exports.oxmysql:update_async("UPDATE fuelstations_creative SET Stock = GREATEST(Stock - ?,0), MoneyEarned = MoneyEarned + ?, Visits = Visits + 1 WHERE Permission = ?",{ Amount, Value or 0, Departmenty })

		if Value and Value > 0 then

            table.insert(Datatable.Historical, { Type = "Fuel", Player = { Passport = Customer or 0, Name = Customer and vRP.FullName(Customer) or "Cliente" }, Value = Value, Amount = Amount })
            vRP.SetSrvData("FuelStations:"..Departmenty,Datatable,true)
		end
	else
        local MaxStock = Config.DefaultMaxStock + SumUpgrade(Config.Upgrades.Stock,Datatable.Upgrades.Stock)
		
		exports.oxmysql:update_async("UPDATE fuelstations_creative SET Stock = LEAST(Stock + ?, ?) WHERE Permission = ?",{ Amount, MaxStock, Departmenty })
	end

	return true
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Connect",function(Passport,source)
	local Result = {}
	local Consult = exports.oxmysql:query_async("SELECT * FROM fuelstations_creative")

	for _,v in ipairs(Consult) do
		Result[v.Permission] = { Name = v.Name, Color = v.Color, Blip = v.Blip, Model = Locations[v.Permission].Model, Coords = Locations[v.Permission].Coords, Anim = Locations[v.Permission].Anim, BlipCoords = Locations[v.Permission].BlipCoords }
	end

	TriggerClientEvent("fuelstations:Connect",source,Result)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport)
	if Division[Passport] then
		Division[Passport] = nil
	end

	if Permissions[Passport] then
		Permissions[Passport] = nil
	end

    if PlayerShipments[Passport] then
        PlayerShipments[Passport] = nil
    end
end)