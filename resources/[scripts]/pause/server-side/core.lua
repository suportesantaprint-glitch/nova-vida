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
Tunnel.bindInterface("pause",Lil)
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Store = {}
local Active = {}
local Salarys = {}
local Settings = { Levels = TableLevel(), HomeBoxes = HomeBoxes, Premium = Premium, Propertys = Propertys, Store = { All = ShopAllDisplay, List = ShopItens }, Furnitures = { All = FurnituresAllDisplay, List = FurnituresItens }, Battlepass = { Necessary = BattlepassPoints, Price = BattlepassPrice, Free = Battlepass.Free, Premium = Battlepass.Premium }, Boxes = Boxes, MarketplaceTax = MarketplaceTax, Daily = #Daily }
local Shopping = {}
local PlayerBox = {}
local Marketplace = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Disconnect()
	local source = source
	vRP.Kick(source,"Desconectado")
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- HOME
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Home()
	local source = source
	local Passport = vRP.Passport(source)
	local Identity = vRP.Identity(Passport)
	local Datatable = vRP.Datatable(Passport)
	if Passport and Datatable and Identity then
		local Experience = {}
		for Index,v in pairs(Works) do
			Experience[#Experience + 1] = { v,Datatable[Index] or 0 }
		end

		local Shop = {}
		for Number = 1,9 do
			if Shopping[Number] then
				Shop[Number] = {
					Index = Shopping[Number].Image,
					Amount = Shopping[Number].Amount,
					Name = Shopping[Number].Name
				}
			end
		end

		local MedicRemaining = parseInt(((vRP.DatatableInformation(Passport,"MedicPlan") or 0) - os.time()) / 86400)
		local MedicPlan = MedicRemaining > 0 and MedicRemaining or 0

		return {
			Player = {
				Medic = MedicPlan,
				Passport = Passport,
				Bank = Identity.Bank,
				Blood = Sanguine(Identity.Blood),
				Gemstone = vRP.UserGemstone(Identity.License),
				Name = Identity.Name.." "..Identity.Lastname,
				Playing = CompleteTimers(vRP.Playing(Passport,"Online"))
			},
			Experience = Experience,
			Shopping = Shop
		}
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADGENERATE
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	local Consult = vRP.Query("entitydata/GetData",{ Name = "Marketplace" })
	Marketplace = Consult and Consult[1] and json.decode(Consult[1].Information) or {}

	for Index,v in pairs(ShopItens) do
		table.insert(Store,{
			Index = Index,
			Price = v.Price,
			Discount = v.Discount,
			Category = v.Category,
			Image = exports.vrp:ItemIndex(Index),
			Name = exports.vrp:ItemName(Index),
			Description = exports.vrp:ItemDescription(Index)
		})
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Config()
	Settings.Battlepass.Finish = vRP.SingleQuery("entitydata/GetData",{ Name = "Battlepass" })
	if not Settings.Battlepass.Finish then
		local CurrentTimer = os.time()
		vRP.Query("entitydata/SetData",{ Name = "Battlepass", Information = CurrentTimer })
		Settings.Battlepass.Finish = CurrentTimer + 2592000
	else
		Settings.Battlepass.Finish = vRP.SingleQuery("entitydata/GetData",{ Name = "Battlepass" }).Information + 2592000
	end
	
	return Settings
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CODE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Code(Name)
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport or Active[Passport] then
        return false
    end

    Active[Passport] = true
    Name = tostring(Name or "")
    if Name == "" or not Name:match("^[A-Za-z0-9_-]+$") then
        Active[Passport] = nil
        return false
    end

    local ConsultCodes = exports.oxmysql:single_async("SELECT * FROM codes_creative WHERE Code = ? LIMIT 1",{ Name })
    if not ConsultCodes then
        TriggerClientEvent("pause:Notify",source,"Aviso","Código inválido.","amarelo")
        Active[Passport] = nil
        return false
    end

    local Already = exports.oxmysql:single_async("SELECT 1 FROM codes_creative_redeemd WHERE Code = ? AND Passport = ? LIMIT 1",{ Name,Passport })
    if Already then
        TriggerClientEvent("pause:Notify",source,"Aviso","Você já resgatou este código.","amarelo")
        Active[Passport] = nil
        return false
    end

    local Used = parseInt(ConsultCodes.Used or 0)
    local Max = parseInt(ConsultCodes.Max or 0)
    if Max > 0 and Used >= Max then
        TriggerClientEvent("pause:Notify",source,"Aviso","Limite de resgate atingido.","amarelo")
        Active[Passport] = nil
        return false
    end

    local Rewards = {}
    if ConsultCodes.Rewards then
        local ok, decoded = pcall(json.decode, ConsultCodes.Rewards)
        if ok and decoded then
            Rewards = decoded
        end
    end

    local function GiveReward(item, amount)
    	amount = parseInt(amount)
    	if amount > 0 and item and item ~= "" then
            vRP.GenerateItem(Passport,item,amount)
        end
    end

    if type(Rewards) == "table" then
        if #Rewards > 0 then
            for _, r in ipairs(Rewards) do
                if type(r) == "table" then
                    GiveReward(r.Item or r.item, r.Amount or r.amount)
                end
            end
        else
            for item, amount in pairs(Rewards) do
                GiveReward(item, amount)
            end
        end
    end

    exports.oxmysql:insert_async("INSERT INTO codes_creative_redeemd (Code,Passport,RedeemdAt) VALUES (?,?,?)",{ Name,Passport,os.time() })
    exports.oxmysql:update_async("UPDATE codes_creative SET Used = Used + 1 WHERE Code = ?",{ Name })

    TriggerClientEvent("pause:Notify",source,"Parabéns","Código resgatado com sucesso","verde")
    Active[Passport] = nil
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- STOREBUY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.StoreBuy(Item,Amount,OtherPassport)
	local Item = Item
	local source = source
	local Amount = parseInt(Amount,true)
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] and ShopItens[Item] then
		Active[Passport] = true

		if Amount > 1 and exports.vrp:ItemUnique(Item) then
			Amount = 1
		end

		local Price = ShopItens[Item].Price
		if ShopItens[Item].Discount < 1.0 then
			Price = Price * ShopItens[Item].Discount
		end

		if OtherPassport then
			if not vRP.MaxItens(OtherPassport,Item,Amount) and vRP.PaymentGems(Passport,Price * Amount) then
				exports["discord"]:Embed("Shopping","**[TIPO]:** Comprou\n**[PASSAPORTE]:** "..Passport.."\n**[ITEM]:** "..Dotted(Amount).."x "..Item.."\n**[DIAMANTES]:** "..Dotted(Price * Amount))
				TriggerClientEvent("pause:Notify",source,"Sucesso","Compra concluída.","verde")

					if vRP.Source(OtherPassport) then
						vRP.GenerateItem(OtherPassport,Item,Amount,true)
					else
						local Selected = GenerateString("DDLLDDLL")
						local Consult = vRP.GetSrvData("Offline:"..OtherPassport,true)

						repeat
							Selected = GenerateString("DDLLDDLL")
						until Selected and not Consult[Selected]
						
						Consult[Selected] = { Item = Item, Amount = Amount }
						vRP.SetSrvData("Offline:"..OtherPassport,Consult,true)
					end

				table.insert(Shopping,1,{
					Amount = Amount,
					Image = exports.vrp:ItemIndex(Item),
					Name = vRP.LowerName(Passport)
				})

				Active[Passport] = nil

				return Amount
			end
		end

		if not vRP.MaxItens(Passport,Item,Amount) and vRP.PaymentGems(Passport,Price * Amount) then
			exports["discord"]:Embed("Shopping","**[TIPO]:** Comprou\n**[PASSAPORTE]:** "..Passport.."\n**[ITEM]:** "..Dotted(Amount).."x "..Item.."\n**[DIAMANTES]:** "..Dotted(Price * Amount))
			TriggerClientEvent("pause:Notify",source,"Sucesso","Compra concluída.","verde")

			vRP.GenerateItem(Passport,Item,Amount,false)

			table.insert(Shopping,1,{
				Amount = Amount,
				Image = exports.vrp:ItemIndex(Item),
				Name = vRP.LowerName(Passport)
			})

			Active[Passport] = nil

			return Amount
		end

		Active[Passport] = nil
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- STOREBUY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.FurnituresBuy(Item,Amount,OtherPassport)
	local Item = Item
	local source = source
	local Amount = parseInt(Amount,true)
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] and FurnituresItens[Item] then
		Active[Passport] = true

		if Amount > 1 and exports.vrp:ItemUnique(Item) then
			Amount = 1
		end

		local Price = FurnituresItens[Item].Price
		if FurnituresItens[Item].Discount < 1.0 then
			Price = Price * FurnituresItens[Item].Discount
		end

		if OtherPassport then
			if not vRP.MaxItens(OtherPassport,Item,Amount) and vRP.PaymentGems(Passport,Price * Amount) then
				exports["discord"]:Embed("Shopping","**[TIPO]:** Comprou\n**[PASSAPORTE]:** "..Passport.."\n**[ITEM]:** "..Dotted(Amount).."x "..Item.."\n**[DIAMANTES]:** "..Dotted(Price * Amount))
				TriggerClientEvent("pause:Notify",source,"Sucesso","Compra concluída.","verde")

				if vRP.Source(OtherPassport) then
					vRP.GenerateItem(OtherPassport,Item,Amount,true)
					TriggerClientEvent("pause:Notify",source,"Sucesso","Entregue ao destinatário.","verde",5000)
				else
					local Selected = GenerateString("DDLLDDLL")
					local Consult = vRP.GetSrvData("Offline:"..OtherPassport,true)

					repeat
						Selected = GenerateString("DDLLDDLL")
					until Selected and not Consult[Selected]

					TriggerClientEvent("pause:Notify",source,"Sucesso","Adicionado a lista de entregas.","verde",5000)
					Consult[Selected] = { Item = Item, Amount = Amount }
					vRP.SetSrvData("Offline:"..OtherPassport,Consult,true)
				end
				
				table.insert(Shopping,1,{
					Amount = Amount,
					Image = exports.vrp:ItemIndex(Item),
					Name = vRP.LowerName(Passport)
				})

				Active[Passport] = nil

				return Amount
			end
		end

		if not vRP.MaxItens(Passport,Item,Amount) and vRP.PaymentGems(Passport,Price * Amount) then
			exports["discord"]:Embed("Shopping","**[TIPO]:** Comprou\n**[PASSAPORTE]:** "..Passport.."\n**[ITEM]:** "..Dotted(Amount).."x "..Item.."\n**[DIAMANTES]:** "..Dotted(Price * Amount))
			TriggerClientEvent("pause:Notify",source,"Sucesso","Compra concluída.","verde")

			vRP.GenerateItem(Passport,Item,Amount,false)

			table.insert(Shopping,1,{
				Amount = Amount,
				Image = exports.vrp:ItemIndex(Item),
				Name = vRP.LowerName(Passport)
			})

			Active[Passport] = nil

			return Amount
		end

		Active[Passport] = nil
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SALARYS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Salarys()
	local source = source
	local CurrentTimer = os.time()
	local Passport = vRP.Passport(source)
	if Passport and (not Salarys[Passport] or Salarys[Passport] < CurrentTimer) then
		local Valuation = vRP.UserSalarys(Passport)
		if Valuation > 0 then
			Salarys[Passport] = CurrentTimer + SalaryCooldown
			vRP.GiveBank(Passport,Valuation,true)
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Propertys()
	local source = source
	local Information = {}
	local Passport = vRP.Passport(source)
	if Passport then
		for Index,v in pairs(Propertys) do
			Information[Index] = exports["crons"]:Check(Passport,"WipePermission",{ Permission = v.Permission }) or (vRP.AmountGroups(v.Permission) > 0 and true) or false
		end
	end

	return Information
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYBUY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.PropertyBuy(Index)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] and Propertys[Index] and Propertys[Index].Permission then
		if not Propertys[Index].Permission then
			TriggerClientEvent("pause:Notify",source,"Atenção","Permissão não encontrada.","amarelo")

			return false
		end

		local Amount = vRP.AmountGroups(Propertys[Index].Permission)
		local Level = vRP.HasPermission(Passport,Propertys[Index].Permission)
		if Amount > 0 and Level and Level > 1 then
			TriggerClientEvent("pause:Notify",source,"Atenção","Propriedade indisponível.","amarelo")

			return false
		end

		Active[Passport] = true

		local Price = Propertys[Index].Price
		if Propertys[Index].Discount < 1.0 then
			Price = parseInt(Price * Propertys[Index].Discount)
		end

		if vRP.PaymentGems(Passport,Price) then
			exports["discord"]:Embed("Propertys","**[PASSAPORTE]:** "..Passport.."\n**[COMPROU]:** "..Propertys[Index].Name.."\n**[VALOR]:** "..Price.."\n**[DURAÇÃO]:** "..CompleteTimers(Propertys[Index].Duration))
			TriggerClientEvent("pause:Notify",source,"Sucesso","Compra concluída.","verde")
			Active[Passport] = nil

			if not vRP.HasPermission(Passport,Propertys[Index].Permission) then
				vRP.SetPermission(Passport,Propertys[Index].Permission,1)
			end

			exports["crons"]:Insert(Passport,"WipePermission",Propertys[Index].Duration / 60,{ Permission = Propertys[Index].Permission })
			return exports["crons"]:Check(Passport,"WipePermission",{ Permission = Propertys[Index].Permission })
		end

		Active[Passport] = nil
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PREMIUM
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Premium()
	local source = source
	local Information = {}
	local Passport = vRP.Passport(source)
	if Passport then
		for Index,v in pairs(Premium) do
			Information[Index] = exports["crons"]:Check(Passport,"RemovePermission",{ Permission = v.Permission })
		end
	end

	return Information
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PREMIUMBUY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.PremiumBuy(Index,Selectable)
	local source = source
	local Data = Premium[Index]
	local Passport = vRP.Passport(source)

	if not Passport or not Data or not Data.Permission or Active[Passport] then
		return false
	end

	Active[Passport] = true

	if Data.Group and not vRP.HasGroup(Passport,Data.Group) then
		TriggerClientEvent("pause:Notify",source,"Atenção","Permissão não encontrada.","amarelo")
		Active[Passport] = nil

		return false
	end

	if Selectable and #Selectable > 0 then
		for _, Model in pairs(Selectable) do
			local Consult = vRP.SingleQuery("vehicles/selectVehicles",{ Passport = Passport, Vehicle = Model })
			if Consult and not Consult.Block then
				TriggerClientEvent("pause:Notify",source,"Aviso","Já possui um <b>"..exports.vrp:VehicleName(Model).."</b>.","amarelo")
				Active[Passport] = nil

				return false
			end
		end
	end

	local Price = Data.Price
	if Data.Discount and Data.Discount < 1.0 then
		Price = math.floor(Price * Data.Discount)
	end

	if not vRP.PaymentGems(Passport,Price) then
		TriggerClientEvent("pause:Notify",source,"Atenção","Diamante insuficiente.","amarelo")
		Active[Passport] = nil

		return false
	end

	TriggerClientEvent("pause:Notify",source,"Sucesso","Compra concluída.","verde")
	exports["discord"]:Embed("Premium","**[PASSAPORTE]:** "..Passport.."\n**[COMPROU]:** "..Data.Name.."\n**[VALOR]:** "..Price.."\n**[DURAÇÃO]:** "..CompleteTimers(Data.Duration))

	if Selectable and #Selectable > 0 then
		for _,Model in pairs(Selectable) do
			if not vRP.SelectVehicle(Passport,Model) then
				exports.oxmysql:insert_async("INSERT INTO vehicles (Passport,Vehicle,Plate,Weight,Tax,Work,Block) VALUES (@Passport,@Vehicle,@Plate,@Weight,@Tax,@Work,@Block)",{ Passport = Passport, Vehicle = Model, Plate = vRP.GeneratePlate(), Weight = exports.vrp:VehicleWeight(Model), Tax = os.time() + Data.Duration, Block = 1, Work = (exports.vrp:VehicleMode(Model) == "Work" and 1 or 0) })
			end

			exports["crons"]:Insert(Passport,"RemoveVehicle",Data.Duration / 60,{ Model = Model })
		end
	end

	if not vRP.HasPermission(Passport,Data.Permission) then
		vRP.SetPermission(Passport,Data.Permission)
	end

	exports["crons"]:Insert(Passport,"RemovePermission",Data.Duration / 60,{ Permission = Data.Permission })

	Active[Passport] = nil

	return exports["crons"]:Check(Passport,"RemovePermission",{ Permission = Data.Permission })
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- BATTLEPASS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Battlepass()
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport then
		return false
	end

	local Consult = vRP.Battlepass(Passport)
	if not Consult then
		return false
	end

	return { Consult.Free,Consult.Premium,Consult.Points,Consult.Active }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- BATTLEPASSRESCUE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.BattlepassRescue(Mode,Number)
	local source = source
	local Passport = vRP.Passport(source)
	local DataItens = Battlepass[Mode] and Battlepass[Mode][Number]

	if not (Passport and DataItens and not Active[Passport]) then
		return false
	end

	Active[Passport] = true

	local Consult = vRP.Battlepass(Passport)
	if not Consult then
		Active[Passport] = nil
		return false
	end

	if Mode == "Premium" and not Consult.Active then
		Active[Passport] = nil
		return false
	end

	local Item = DataItens.Item
	local Amount = DataItens.Amount
	local Next = (Consult[Mode] or 0) + 1
	local HasWeight = vRP.CheckWeight(Passport,Item,Amount)

	if HasWeight and Next == Number and vRP.BattlepassPayment(Passport,Mode,BattlepassPoints) then
		exports["discord"]:Embed("Battlepass","**[PASSAPORTE]:** "..Passport.."\n**[MODO]:** "..Mode.."\n**[VALOR]:** "..Number)
		TriggerClientEvent("pause:Notify",source,"Sucesso","Resgate concluído.","verde")
		vRP.GenerateItem(Passport,Item,Amount)
		Active[Passport] = nil

		return true
	end

	Active[Passport] = nil

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- BATTLEPASSBUY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.BattlepassBuy()
	local source = source
	local Passport = vRP.Passport(source)

	if not Passport or Active[Passport] then
		return false
	end

	Active[Passport] = true

	local Consult = vRP.Battlepass(Passport)
	local ValidPeriod = Settings.Battlepass.Finish >= os.time()

	if Consult and ValidPeriod and not Consult.Active and vRP.PaymentGems(Passport,BattlepassPrice) then
		exports["discord"]:Embed("Battlepass","**[PASSAPORTE]:** "..Passport.."\n**[MODO]:** Comprou\n**[VALOR]:** "..BattlepassPrice)
		TriggerClientEvent("pause:Notify",source,"Sucesso","Compra concluída.","verde")
		vRP.BattlepassBuy(Passport)
		Active[Passport] = nil

		return true
	end

	Active[Passport] = nil

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- OPENBOX
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.OpenBox(Number)
		local Number = Number
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] and not PlayerBox[Passport] then
		Active[Passport] = true

		local Price = Boxes[Number].Price
		if Boxes[Number].Discount < 1.0 then
			Price = Price * Boxes[Number].Discount
		end

		if vRP.PaymentGems(Passport,Price) then
			PlayerBox[Passport] = RandPercentage(Boxes[Number].Rewards)

			SetTimeout(6000,function()
				local Name = PlayerBox[Passport].Id

				exports["discord"]:Embed("Boxes","**[PASSAPORTE]:** "..Passport.."\n**[CAIXA]:** "..Boxes[Number].Name.."\n**[PRÊMIO]:** "..Boxes[Number].Rewards[Name].Amount.."x "..Boxes[Number].Rewards[Name].Item)
				vRP.GenerateItem(Passport,Boxes[Number].Rewards[Name].Item,Boxes[Number].Rewards[Name].Amount)
				PlayerBox[Passport] = nil
				Active[Passport] = nil
			end)

			return PlayerBox[Passport].Id
		end

		Active[Passport] = nil
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MARKETPLACE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Marketplace()
	local Return = {}
	local CurrentTimer = os.time()
	for Index,v in pairs(Marketplace) do
		if v.timer > CurrentTimer then
			local Table = {
				Index = Index,
				Image = v.key,
				Price = v.price,
				Amount = v.quantity,
				Passport = v.passport,
				Name = exports.vrp:ItemName(v.item)
			}

			local Split = splitString(v.item)
			if Split[2] then
				local Loaded = exports.vrp:ItemLoads(v.item)
				if Loaded then
					Table.Charges = parseInt(Split[2] * (100 / Loaded))
				end

				local Durability = exports.vrp:ItemDurability(v.item)
				if Durability then
					Table.Durability = parseInt(CurrentTimer - Split[2])
					Table.Days = Durability
				end
			end

			table.insert(Return,Table)
		end
	end

	return Return
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MARKETPLACEINVENTORY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.MarketplaceInventory(Mode)
	local source = source
	local Passport = vRP.Passport(source)

	if not (Passport and Mode) then
		return false
	end

	local Return = {}
	local CurrentTimer = os.time()

	if Mode == "Create" then
		local Inv = vRP.Inventory(Passport)
		for Index,v in pairs(Inv) do
			if not BlockMarket(v.item) and not vRP.CheckDamaged(v.item) then
				local Table = {
					Index = Index,
					Key = v.item,
					Amount = v.amount,
					Image = exports.vrp:ItemIndex(v.item),
					Name = exports.vrp:ItemName(v.item)
				}

				local Split = splitString(v.item)
				if Split[2] then
					local Loaded = exports.vrp:ItemLoads(v.item)
					if Loaded then
						Table.Charges = parseInt(Split[2] * (100 / Loaded))
					end

					local Durability = exports.vrp:ItemDurability(v.item)
					if Durability then
						Table.Durability = parseInt(CurrentTimer - Split[2])
						Table.Days = Durability
					end
				end

				table.insert(Return,Table)
			end
		end
	elseif Mode == "Announce" then
		for Index,v in pairs(Marketplace) do
			if Passport == v.passport then
				local Table = {
					Key = Index,
					Image = v.key,
					Price = v.price,
					Amount = v.quantity,
					Name = exports.vrp:ItemName(v.item)
				}

				local Split = splitString(v.item)
				if Split[2] then
					local Loaded = exports.vrp:ItemLoads(v.item)
					if Loaded then
						Table.Charges = parseInt(Split[2] * (100 / Loaded))
					end

					local Durability = exports.vrp:ItemDurability(v.item)
					if Durability then
						Table.Durability = parseInt(CurrentTimer - Split[2])
						Table.Days = Durability
					end
				end

				table.insert(Return,Table)
			end
		end
	end

	return Return
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MARKETPLACEANNOUNCE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.MarketplaceAnnounce(Table)
	local source = source
	local Item = Table.Item
	local Price = Table.Price
	local Quantity = Table.Amount
	local Passport = vRP.Passport(source)
	if Passport and Item and Price and Quantity and not BlockMarket(Item) and vRP.PaymentFull(Passport,Price * MarketplaceTax) and vRP.TakeItem(Passport,Item,Quantity) then
		repeat
			Selected = GenerateString("DDLLDDLL")
		until Selected and not Marketplace[Selected]

		Marketplace[Selected] = {
			item = Item,
			price = Price,
			quantity = Quantity,
			passport = Passport,
			key = exports.vrp:ItemIndex(Item),
			timer = os.time() + 259200
		}

		exports["discord"]:Embed("Marketplace","**[MODO]:** Anúncio\n**[PASSAPORTE]:** "..Passport.."\n**[ITEM]:** "..Dotted(Quantity).."x "..Item.."\n**[VALOR]:** $"..Dotted(Price))

		return true
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MARKETPLACECANCEL
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.MarketplaceCancel(Selected)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and Marketplace[Selected] and Marketplace[Selected].passport and Marketplace[Selected].passport == Passport and vRP.GiveItem(Passport,Marketplace[Selected].item,Marketplace[Selected].quantity) then
		exports["discord"]:Embed("Marketplace","**[MODO]:** Cancelar\n**[PASSAPORTE]:** "..Passport.."\n**[ITEM]:** "..Dotted(Marketplace[Selected].quantity).."x "..Marketplace[Selected].item.."\n**[VALOR]:** $"..Dotted(Marketplace[Selected].price))
		Marketplace[Selected] = nil

		return true
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MARKETPLACEBUY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.MarketplaceBuy(Selected)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] and Marketplace[Selected] and Marketplace[Selected].passport and Marketplace[Selected].passport ~= Passport then
		Active[Passport] = true

		if vRP.MaxItens(Passport,Marketplace[Selected].item,Marketplace[Selected].quantity) then
			TriggerClientEvent("pause:Notify",source,"Atenção","Limite atingido.","vermelho")
			Active[Passport] = nil

			return false
		end

		if vRP.PaymentFull(Passport,Marketplace[Selected].price) and vRP.GiveItem(Passport,Marketplace[Selected].item,Marketplace[Selected].quantity) then
			exports["discord"]:Embed("Marketplace","**[MODO]:** Compra\n**[PASSAPORTE]:** "..Passport.."\n**[VENDEDOR]:** "..Marketplace[Selected].passport.."\n**[ITEM]:** "..Dotted(Marketplace[Selected].quantity).."x "..Marketplace[Selected].item.."\n**[VALOR]:** $"..Dotted(Marketplace[Selected].price))
			TriggerClientEvent("pause:Notify",source,"Sucesso","Compra concluída.","verde")
			vRP.GiveBank(Marketplace[Selected].passport,Marketplace[Selected].price)
			Marketplace[Selected] = nil
			Active[Passport] = nil

			return true
		end

		Active[Passport] = nil
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- RANKING
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Ranking(ColumnOrDirection,DirectionOrNil)
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport or Active[Passport] then
		return {}
	end

	Active[Passport] = true

	local Column = ColumnOrDirection
	local Direction = DirectionOrNil

	if Direction == nil then
		Direction = Column
		Column = "Hours"
	end

	Direction = type(Direction) == "string" and Direction:upper() or "DESC"
	if Direction ~= "ASC" then
		Direction = "DESC"
	end

	local Ranking = {}
	if Column == "Hours" then
		local Query = string.format("SELECT Name,JSON_UNQUOTE(JSON_EXTRACT(Information,'$.Online')) AS Online FROM entitydata WHERE JSON_EXTRACT(Information,'$.Online') IS NOT NULL ORDER BY CAST(JSON_UNQUOTE(JSON_EXTRACT(Information,'$.Online')) AS UNSIGNED) %s LIMIT 50",Direction)
		local Consult = exports.oxmysql:query_async(Query)
		if Consult and #Consult > 0 then
			for _,v in ipairs(Consult) do
				local OtherPassport = tonumber(SplitTwo(v.Name,":"))
				if OtherPassport then
					local Identity = vRP.Identity(OtherPassport)
					if Identity then
						local Deaths = tonumber(Identity.Death) or 0
						local Kills = tonumber(Identity.Killed) or 0
						local Hours = tonumber(v.Online) or 0

						table.insert(Ranking,{
							Death = Deaths,
							Killed = Kills,
							Ratio = Deaths > 0 and (Kills / Deaths) or Kills,
							Hours = Hours,
							Name = ("%s %s"):format(Identity.Name,Identity.Lastname),
							Passport = OtherPassport,
							Blood = Sanguine(Identity.Blood) or "",
							LastLogin = Identity.Login or 0
						})
					end
				end
			end
		end
	else
		local AllowedColumns = {
			["Killed"] = true,
			["Death"] = true
		}
		if not AllowedColumns[Column] then
			Column = "Killed"
		end

		local Query = string.format("SELECT id,Name,Lastname,Blood,Login,Killed,Death FROM characters WHERE Deleted = '0' ORDER BY %s %s LIMIT 50",Column,Direction)
		local Consult = exports.oxmysql:query_async(Query)
		if Consult and #Consult > 0 then
			for _,v in ipairs(Consult) do
				local Deaths = tonumber(v.Death) or 0
				local Kills = tonumber(v.Killed) or 0

				table.insert(Ranking,{
					Death = Deaths,
					Killed = Kills,
					Ratio = Deaths > 0 and (Kills / Deaths) or Kills,
					Hours = vRP.Playing(v.id,"Online"),
					Name = ("%s %s"):format(v.Name,v.Lastname),
					Passport = v.id,
					Blood = Sanguine(v.Blood) or "",
					LastLogin = v.Login or 0
				})
			end
		end
	end

	Active[Passport] = nil

	return Ranking
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DAILY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Daily()
	local Source = source
	local Passport = vRP.Passport(Source)

	if not Passport then return false end

	local Identity = vRP.Identity(Passport)
	local DailyInformation = splitString(Identity.Daily,"-")

	return { string.format("%s-%s-%s",DailyInformation[1],DailyInformation[2],DailyInformation[3]), tonumber(DailyInformation[4]), #Daily }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DAILYRESCUE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.DailyRescue(Day)
	local source = source
	local Passport = vRP.Passport(source)

	if Passport then
		local Rewards = Daily[Day]
		for Item, Amount in pairs(Rewards) do
			vRP.GenerateItem(Passport, Item, Amount, false)
		end

		TriggerClientEvent("pause:Notify", source, "Sucesso", "Recompensa recebida.", "verde")
		vRP.UpdateDaily(Passport, source, os.date("%d-%m-%Y").."-"..Day)

		return true
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- STATISTICS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Statistics()
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport then
        return { Kills = 0, Deaths = 0, Logs = {} }
    end

    local Identity = vRP.Identity(Passport)
    if not Identity then
        return { Kills = 0, Deaths = 0, Logs = {} }
    end

    local Kills = 0
    local Deaths = 0
    local Logs = {}

    local Consult = exports.oxmysql:query_async("SELECT * FROM deaths_creative WHERE Attacker = ? OR Victim = ? ORDER BY Timestamp DESC LIMIT 50",{ Passport,Passport })
    if Consult and #Consult > 0 then
        for _,v in ipairs(Consult) do
            local AttackerPassport = tonumber(v.Attacker) or 0
            local VictimPassport = tonumber(v.Victim) or 0
            local AttackerIdentity = vRP.Identity(AttackerPassport)
            local VictimIdentity = vRP.Identity(VictimPassport)

            if AttackerPassport == Passport then
                Kills = Kills + 1
            end

            if VictimPassport == Passport then
                Deaths = Deaths + 1
            end
            
            local WeaponName = v.Weapon or "Desconhecida"
            
            local WeaponHash = tonumber(WeaponName)
            if WeaponHash and WeaponsHash[WeaponHash] then
                WeaponName = WeaponsHash[WeaponHash]
            end
            
            local AttackerName = AttackerIdentity and (AttackerIdentity.Name.." "..AttackerIdentity.Lastname) or "Desconhecido"
            local VictimName = VictimIdentity and (VictimIdentity.Name.." "..VictimIdentity.Lastname) or "Desconhecido"
            
            table.insert(Logs,{ Killer = { Passport = AttackerPassport, Name = AttackerName }, Victim = { Passport = VictimPassport, Name = VictimName }, Weapon = WeaponName, Date = tonumber(v.Timestamp) or os.time() })
        end
    end

    return { Kills = Kills, Deaths = Deaths, Logs = Logs }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PAUSE:WIPEBATTLEPASS
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("pause:WipeBattlepass",function(Timer)
	Settings.Battlepass.Finish = Timer + 2592000
	TriggerClientEvent("pause:UpdateConfig",-1)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport)
	if PlayerBox[Passport] then
		PlayerBox[Passport] = nil
	end

	if Active[Passport] then
		Active[Passport] = nil
	end

	if Salarys[Passport] then
		Salarys[Passport] = nil
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SAVESERVER
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("SaveServer",function(Silenced)
	vRP.Query("entitydata/SetData",{ Name = "Marketplace", Information = json.encode(Marketplace) })

	if not Silenced then
		print("O resource ^2Pause^7 salvou os dados.")
	end
end)