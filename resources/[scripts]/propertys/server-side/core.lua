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
Tunnel.bindInterface("propertys",Lil)
vKEYBOARD = Tunnel.getInterface("keyboard")
vSKINSHOP = Tunnel.getInterface("skinshop")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Lock = {}
local Saved = {}
local Inside = {}
local Active = {}
local Robbery = {}
local Markers = {}
local Interior = {}
local Objects = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:ROBBERY
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Robbery")
AddEventHandler("propertys:Robbery",function(Name)
	local source = source
	local Passport = vRP.Passport(source)

	if not Passport or Active[Passport] then
		return false
	end

	Active[Passport] = true
	TriggerClientEvent("dynamic:Close",source)

	local Service = vRP.HasService(Passport,"Policia")
	local Lockpick = vRP.ConsultItem(Passport,"lockpick")
	local LockpickPlus = vRP.ConsultItem(Passport,"lockpickplus")
	local Consult = vRP.SingleQuery("propertys/Exist",{ Name = Name })
	local Warehouse = Consult and Consult.Interior == "Galpao"

	if not Warehouse and (Service or ((Lockpick or LockpickPlus) and vRP.Task(source,5,5000))) then
		Saved[Name] = Saved[Name] or (Consult and Consult.Interior or exports["propertys"]:Informations())
		Robbery[Name] = Robbery[Name] or {}

		if not Service then
			if Lockpick then
				vRP.RemoveItem(Passport,Lockpick.Item,1,true)
			end

			if Consult then
				local Online = vRP.Source(Consult.Passport)
				if Online then
					TriggerClientEvent("Notify",Online,"Alerta de Segurança","Sua propriedade está sendo invadida, chame as autoridades para ajudar no local.","policia",10000)
				end
			end
		end

		TriggerClientEvent("propertys:Enter",source,Name,Saved[Name])
	end

	Active[Passport] = nil
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:ROBBERYITEM
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:RobberyItem")
AddEventHandler("propertys:RobberyItem",function(Number,Name)
	local source = source
	local Passport = vRP.Passport(source)

	if not (Passport and Robbery[Name]) then
		return false
	end

	local Lockpick = vRP.ConsultItem(Passport,"lockpick")
	local LockpickPlus = vRP.ConsultItem(Passport,"lockpickplus")
	if not (Lockpick or LockpickPlus) then
		return false
	end

	if Robbery[Name][Number] then
		TriggerClientEvent("chest:Open",source,"Propertys:"..Name..":"..Number,"Custom",false,true)

		return false
	end

	local Locker = (Number == "Locker")
	if (Locker and not vRP.LetterGame(source)) or (not Locker and not vRP.Task(source,5,5000)) then
		if Lockpick and math.random(100) >= 95 then
			vRP.RemoveItem(Passport,Lockpick.Item,1,true)
		end

		local Coords = Propertys[Name].Coords
		TriggerClientEvent("sounds:Area",-1,"alarm",1.0,Coords,75)
		TriggerClientEvent("sounds:Area",-1,"alarm",1.0,vRP.GetEntityCoords(source),125,GetPlayerRoutingBucket(source))

		exports.vrp:CallPolice({
			Source = source,
			Passport = Passport,
			Coords = Coords,
			Permission = "Policia",
			Name = "Roubo a Propriedade",
			Wanted = 30,
			Code = 31,
			Color = 44
		})

		return false
	end

	local Container = "Propertys:"..Name..":"..Number
	local Itens = Locker and LockerItens or OtherItens
	local Amount = Locker and 1 or math.random(3)

	if vRP.MountContainer(Passport,Container,Itens,Amount,false,Locker and 675 or 775,GlobalState.Blackout and { Item = "dirtydollar", Amount = math.random(100,250) } or false) then
		TriggerClientEvent("chest:Open",source,Container,"Custom",false,true)
	end

	TriggerClientEvent("propertys:RemCircleZone",source,Number)
	Robbery[Name][Number] = true
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- POLICE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Police(Outside,Inside)
	local source = source
	local Passport = vRP.Passport(source)

	if not Passport then
		return false
	end

	TriggerClientEvent("sounds:Area",-1,"alarm",1.0,Outside,75)
	TriggerClientEvent("sounds:Area",-1,"alarm",1.0,Inside,125,GetPlayerRoutingBucket(source))

	exports.vrp:CallPolice({
		Source = source,
		Passport = Passport,
		Coords = Outside,
		Permission = "Policia",
		Name = "Roubo a Propriedade",
		Wanted = 300,
		Code = 31,
		Color = 44
	})
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Propertys(Name)
	local source = source
	local Passport = vRP.Passport(source)

	if not Passport then
		return false
	end

	if Name == "Hotel" then
		return vRP.Scalar("propertys/Count",{ Passport = Passport }) <= 0 and "Hotel" or false
	end

	local Consult = vRP.SingleQuery("propertys/Exist",{ Name = Name })
	if not Consult then
		return "Nothing"
	end

	if Consult.Passport ~= Passport and Lock[Name] and not vRP.InventoryFull(Passport,"propertys-"..Consult.Serial) then
		return false
	end

	if not Saved[Name] then
		Saved[Name] = Consult.Interior
	end

	local Interior = Saved[Name]
	local CurrentTimer = os.time()
	local Price = Informations[Interior].Price * 0.25
	local Tax = CompleteTimers(Consult.Tax - CurrentTimer)

	if CurrentTimer > Consult.Tax then
		Tax = "Efetue o pagamento da <b>Hipoteca</b>."

		if vRP.Request(source,"Propriedades","Deseja pagar a hipoteca de <b>"..Currency..Dotted(Price).."</b>?") and vRP.PaymentFull(Passport,Price) then
			TriggerClientEvent("Notify",source,"Propriedades","Pagamento concluído.","verde",5000)
			vRP.Update("propertys/Tax",{ Name = Name })
			Tax = CompleteTimers(2592000)
		else
			return false
		end
	end

	return {
		Owner = Consult.Passport,
		Interior = Interior,
		Tax = Tax
	}
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TOGGLE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Toggle(Name,Mode)
	local source = source
	local Passport = vRP.Passport(source)
	local Ped = GetPlayerPed(source)
	local Coords = GetEntityCoords(Ped)

	if not Passport then
		return false
	end

	if Mode == "Exit" then
		Inside[Passport] = nil
		Interior[Passport] = nil
		exports.vrp:Bucket(source,"Exit")
		TriggerEvent("vRP:ReloadWeapons",source)
	else
		TriggerEvent("DebugWeapons",Passport)
		Inside[Passport] = Coords
		Interior[Passport] = Name

		local Bucket = Name == "Hotel" and (200000 + Passport) or (100000 + string.sub(Name,-4))
		exports.vrp:Bucket(source,"Enter",Bucket)

		if Name ~= "Hotel" then
			return vRP.GetSrvData("Probjects:"..Name,true)
		end
	end

	TriggerEvent("animals:Delete",Passport,source)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:BUY
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Buy")
AddEventHandler("propertys:Buy",function(Name)
	local source = source
	local Split = splitString(Name)
	local Passport = vRP.Passport(source)

	if not Passport or exports.bank:CheckTaxes(Passport) or exports.bank:CheckFines(Passport) then
		return false
	end

	local Name,Interior,Mode = Split[1],Split[2],Split[3]
	local Consult = vRP.SingleQuery("propertys/Exist",{ Name = Name })

	if Consult then
		return false
	end

	TriggerClientEvent("dynamic:Close",source)

	if not vRP.Request(source,"Propriedades","Deseja comprar a propriedade?") then
		return false
	end

	local Payment = false
	if Mode == "Dollar" then
		Payment = vRP.PaymentFull(Passport,Informations[Interior].Price)
	elseif Mode == "Gemstone" then
		Payment = vRP.PaymentGems(Passport,Informations[Interior].Gemstone)
	end

	if not Payment then
		TriggerClientEvent("Notify",source,"Propriedades",Mode == "Dollar" and "Dinheiro insuficiente." or "Diamante insuficiente.","amarelo",10000)

		return false
	end

	Lock[Name] = true
	Saved[Name] = Interior
	local Serial = PropertysSerials()
	vRP.GiveItem(Passport,"propertys-"..Serial,3,true)
	TriggerClientEvent("Notify",source,"Propriedades","Compra concluída.","verde",10000)

	if Mode == "Dollar" then
		exports.bank:AddTaxes(Passport,"Propriedades",Informations[Interior].Price,"Compra de propriedade.")
	end

	vRP.Query("propertys/Buy",{
		Name = Name,
		Interior = Interior,
		Passport = Passport,
		Serial = Serial,
		Vault = Informations[Interior].Vault or 0,
		Fridge = Informations[Interior].Fridge or 0
	})

	Markers[Name] = true
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:LOCK
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Lock")
AddEventHandler("propertys:Lock",function(Name)
	local source = source
	local Passport = vRP.Passport(source)
	local Consult = vRP.SingleQuery("propertys/Exist",{ Name = Name })

	if not (Passport and Consult) then
		return false
	end

	if Consult.Passport ~= Passport and not vRP.InventoryFull(Passport,"propertys-"..Consult.Serial) then
		return false
	end

	Lock[Name] = not Lock[Name]

	TriggerClientEvent("Notify",source,"Aviso","Propriedade "..(Lock[Name] and "trancada" or "destrancada")..".","default",10000)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:INTERIOR
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Interior")
AddEventHandler("propertys:Interior",function(Table)
	local source = source
	local Split = splitString(Table)
	local Passport = vRP.Passport(source)
	local Name,Interior = Split[1],Split[2]
	local Consult = vRP.SingleQuery("propertys/Exist",{ Name = Name })

	if not Passport or not Consult or Consult.Passport ~= Passport or Consult.Interior == Interior then
		return false
	end

	TriggerClientEvent("dynamic:Close",source)

	local InteriorPrice = Informations[Interior].Gemstone
	local CurrentPrice = Informations[Consult.Interior].Gemstone
	if vRP.Request(source,"Propriedades","Deseja efetuar a troca do interior atual para o <b>"..Interior.."</b> por <b>"..Dotted(InteriorPrice - CurrentPrice).." diamantes</b>?") then
		if vRP.PaymentGems(Passport,InteriorPrice - CurrentPrice) then
			exports.oxmysql:update_async("UPDATE propertys SET Interior = ? WHERE Name = ?",{ Interior,Name })
			TriggerClientEvent("Notify",source,"Propriedades","Compra concluída.","verde",10000)
			Saved[Name] = Interior
		else
			TriggerClientEvent("Notify",source,"Propriedades","Diamante insuficiente.","amarelo",10000)
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:SELL
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Sell")
AddEventHandler("propertys:Sell",function(Name)
	local source = source
	local Passport = vRP.Passport(source)

	if not Passport or Active[Passport] then
		return false
	end

	Active[Passport] = true

	local Consult = vRP.SingleQuery("propertys/Exist",{ Name = Name })
	if not (Consult and Consult.Passport == Passport) then
		Active[Passport] = nil

		return false
	end

	TriggerClientEvent("dynamic:Close",source)

	local Price = Informations[Consult.Interior].Price * 0.25
	if vRP.Request(source,"Propriedades","Vender por <b>"..Currency..Dotted(Price).."</b>?") then
		if Markers[Name] then
			Markers[Name] = nil
		end

		vRP.GiveBank(Passport,Price)
		vRP.RemSrvData("Vault:"..Name)
		vRP.RemSrvData("Fridge:"..Name)
		vRP.Query("propertys/Sell",{ Name = Name })

		TriggerClientEvent("garages:Clean",-1,Name)
		TriggerClientEvent("Notify",source,"Propriedades","Venda concluída.","verde",10000)
	end

	Active[Passport] = nil
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:TRANSFER
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Transfer")
AddEventHandler("propertys:Transfer",function(Name)
	local source = source
	local Passport = vRP.Passport(source)

	if not Passport or Active[Passport] then
		return false
	end

	Active[Passport] = true

	local Consult = vRP.SingleQuery("propertys/Exist",{ Name = Name })
	if not (Consult and Consult.Passport == Passport) then
		Active[Passport] = nil

		return false
	end

	TriggerClientEvent("dynamic:Close",source)

	local Keyboard = vKEYBOARD.Primary(source,"Passaporte")
	local OtherPassport = Keyboard and Keyboard[1]

	if OtherPassport and vRP.Identity(OtherPassport) and vRP.Request(source,"Propriedades","Deseja transferir para o passaporte <b>"..OtherPassport.."</b>?") then
		vRP.Update("propertys/Transfer",{ Name = Name, Passport = OtherPassport })
		TriggerClientEvent("Notify",source,"Propriedades","Transferência concluída.","verde",10000)
	end

	Active[Passport] = nil
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:CREDENTIALS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Credentials")
AddEventHandler("propertys:Credentials",function(Name)
	local source = source
	local Passport = vRP.Passport(source)
	local Consult = vRP.SingleQuery("propertys/Exist",{ Name = Name })

	if not (Passport and Consult and Consult.Passport == Passport) then
		return false
	end

	TriggerClientEvent("dynamic:Close",source)

	if vRP.Request(source,"Propriedades","Lembre-se que ao prosseguir todos os cartões atuais deixam de funcionar, deseja prosseguir?") then
		local Serial = PropertysSerials()
		vRP.Update("propertys/Credentials",{ Name = Name, Serial = Serial })
		vRP.GiveItem(Passport,"propertys-"..Serial,Consult.Item,true)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:ITEM
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Item")
AddEventHandler("propertys:Item",function(Name)
	local source = source
	local Passport = vRP.Passport(source)
	local Consult = vRP.SingleQuery("propertys/Exist",{ Name = Name })

	if not (Passport and Consult and Consult.Passport == Passport and Consult.Item < 5) then
		return false
	end

	TriggerClientEvent("dynamic:Close",source)

	local Price = 150000
	if vRP.Request(source,"Propriedades","Comprar uma chave adicional por <b>"..Currency..Dotted(Price).."</b>?") then
		if vRP.PaymentFull(Passport,Price) then
			vRP.Update("propertys/Item",{ Name = Name })
			vRP.GiveItem(Passport,"propertys-"..Consult.Serial,1,true)
		else
			TriggerClientEvent("Notify",source,"Aviso","Dinheiro insuficiente.","amarelo",10000)
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLOTHES
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Clothes()
	local source = source
	local Passport = vRP.Passport(source)

	if not Passport then
		return {}
	end

	local Clothes = {}
	local Consult = vRP.GetSrvData("Wardrobe:"..Passport,true)
	for Table in pairs(Consult) do
		table.insert(Clothes,Table)
	end

	return Clothes
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:CLOTHES:SAVE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Clothes:Save")
AddEventHandler("propertys:Clothes:Save",function(Mode)
	local source = source
	local Passport = vRP.Passport(source)

	if not Passport then
		return false
	end

	local Split = splitString(Mode)
	local Property,Serial,Prop = Split[1],Split[2],Split[3]
	local Consult = vRP.GetSrvData("Wardrobe:"..Property..":"..Serial,true)

	if CountTable(Consult) >= Wardrobes[Prop] then
		TriggerClientEvent("Notify",source,"Armário","Limite atingido de roupas.","amarelo",10000)

		return false
	end

	local Keyboard = vKEYBOARD.Primary(source,"Nome")
	if Keyboard then
		local Check = sanitizeString(Keyboard[1],"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
		if string.len(Check) >= 4 then
			if not Consult[Check] then
				Consult[Check] = vSKINSHOP.Customization(source)
				vRP.SetSrvData("Wardrobe:"..Property..":"..Serial,Consult,true)
				TriggerClientEvent("dynamic:Close",source)
				TriggerClientEvent("dynamic:AddMenu",source,Check,"Informações da vestimenta.",Check,"wardrobe")
				TriggerClientEvent("dynamic:AddButton",source,"Aplicar","Vestir-se com as vestimentas.","propertys:Clothes","Apply-"..Check,Check,true)
				TriggerClientEvent("dynamic:AddButton",source,"Remover","Deletar a vestimenta do armário.","propertys:Clothes","Delete-"..Check,Check,true,true)
			end
		else
			TriggerClientEvent("Notify",source,"Armário","Nome escolhido precisa possuir mínimo de 4 letras.","amarelo",10000)
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:CLOTHES:APPLY
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Clothes:Apply")
AddEventHandler("propertys:Clothes:Apply",function(Mode)
	local source = source
	local Passport = vRP.Passport(source)

	if not Passport then
		return false
	end

	local Split = splitString(Mode)
	local Property,Serial,Name = Split[1],Split[2],Split[3]
	local Consult = vRP.GetSrvData("Wardrobe:"..Property..":"..Serial,true)

	if Consult[Name] then
		TriggerClientEvent("skinshop:Apply",source,Consult[Name],true)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:CLOTHES:DELETE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Clothes:Delete")
AddEventHandler("propertys:Clothes:Delete",function(Mode)
	local source = source
	local Passport = vRP.Passport(source)

	if not Passport then
		return false
	end

	local Split = splitString(Mode)
	local Property,Serial,Name = Split[1],Split[2],Split[3]
	local Consult = vRP.GetSrvData("Wardrobe:"..Property..":"..Serial,true)

	if Consult[Name] then
		Consult[Name] = nil
		vRP.SetSrvData("Wardrobe:"..Property..":"..Serial,true)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYSSERIALS
-----------------------------------------------------------------------------------------------------------------------------------------
function PropertysSerials()
	repeat
		Serial = GenerateString("LDLDLDLDLD")
		Consult = vRP.SingleQuery("propertys/Serial",{ Serial = Serial })
	until Serial and not Consult

	return Serial
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PERMISSION
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Permission(Name)
	local source = source
	local Passport = vRP.Passport(source)

	if not Passport then
		return false
	end

	if Name == "Hotel" then
		return true
	end

	local Consult = vRP.SingleQuery("propertys/Exist",{ Name = Name })
	if Consult and vRP.InventoryFull(Passport,"propertys-"..Consult.Serial) or Consult.Passport == Passport then
		return true
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MOUNT
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Mount(Name,Mode)
	local Weight = 25
	local source = source
	local Passport = vRP.Passport(source)
	local SplitChest = splitString(Mode)

	if not Passport or not Name or not Mode then
		return false
	end

	if Name == "Hotel" then
		Name = "Hotel:"..Passport
	else
		local Consult = vRP.SingleQuery("propertys/Exist",{ Name = Name })
		if Consult and Chests[SplitChest[2]] then
			Weight = Chests[SplitChest[2]]
		end
	end

	local function ProcessItem(Slot,v,Prefix,Key,Save)
		if v.amount <= 0 or not exports.vrp:ItemExist(v.item) then
			if Prefix == "Inventory" then
				vRP.CleanSlot(Passport,Slot)
			elseif Prefix == "Chest" then
				vRP.CleanSlotChest(Key,Slot,Save)
			end

			return false
		end

		v.key = v.item

		local Split = splitString(v.item)
		local Item = Split[1]

		if not v.desc then
			if Item == "vehiclekey" and Split[3] then
				local Consult = exports.oxmysql:single_async("SELECT * FROM vehicles WHERE Plate = ? LIMIT 1",{ Split[3] })
				if Consult and VehicleExist(Consult.Vehicle) then
					v.desc = "Proprietário: <common>"..vRP.FullName(Consult.Passport).."</common><br>Modelo: <common>"..exports.vrp:VehicleName(Consult.Vehicle).."</common><br>Placa: <common>"..Split[3].."</common>"
				end
			elseif Item == "propertys" and Split[2] then
				local Consult = exports.oxmysql:single_async("SELECT * FROM propertys WHERE Serial = ? LIMIT 1",{ Split[2] })
				if Consult then
					v.desc = "Proprietário: <common>"..vRP.FullName(Consult.Passport).."</common>"
				end
			elseif exports.vrp:ItemNamed(Item) and Split[2] and vRP.Identity(Split[2]) then
				if Item == "identity" then
					v.desc = "Passaporte: <rare>"..Dotted(Split[2]).."</rare><br>Nome: <rare>"..vRP.FullName(Split[2]).."</rare><br>Telefone: <rare>"..vRP.Phone(Split[2]).."</rare>"
				else
					v.desc = "Proprietário: <common>"..vRP.FullName(Split[2]).."</common>"
				end
			end
		end

		if Split[2] then
			local Loaded = exports.vrp:ItemLoads(v.item)
			if Loaded then
				v.charges = parseInt(Split[2] * (100 / Loaded))
			end

			if exports.vrp:ItemDurability(v.item) then
				v.durability = parseInt(os.time() - Split[2])
				v.days = exports.vrp:ItemDurability(v.item)
			end
		end

		return v
	end

	local Primary = {}
	local Secondary = {}
	local Inventory = vRP.Inventory(Passport)
	local Chest = vRP.GetSrvData("Vault:"..Name..":"..SplitChest[1],true)

	for Slot,v in pairs(Inventory) do
		local Processed = ProcessItem(Slot,v,"Inventory")
		if Processed then
			Primary[Slot] = Processed
		end
	end

	for Slot,v in pairs(Chest) do
		local Processed = ProcessItem(Slot,v,"Chest","Vault:"..Name..":"..SplitChest[1],true)
		if Processed then
			Secondary[Slot] = Processed
		end
	end

	return Primary,Secondary,vRP.GetWeight(Passport),Weight,vRP.InventorySlots(Passport)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- STORE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Store(Item,Slot,Amount,Target,Name,Mode)
	local source = source
	local Amount = parseInt(Amount,true)
	local Passport = vRP.Passport(source)
	local SplitChest = splitString(Mode)

	if not Passport then
		return false
	end

	if not Chests[SplitChest[2]] then
		TriggerClientEvent("inventory:Update",source)

		return false
	end

	if Name == "Hotel" then
		if vRP.StoreChest(Passport,Mode..":Hotel:"..Passport,Amount,25,Slot,Target,true) then
			TriggerClientEvent("inventory:Update",source)
		end

		return false
	end

	local Consult = vRP.SingleQuery("propertys/Exist",{ Name = Name })
	if Consult then
		if Item == "diagram" then
			if vRP.TakeItem(Passport,Item,Amount,false,Slot) then
				vRP.Update("propertys/"..Mode,{ Name = Name, Weight = 10 * Amount })
				TriggerClientEvent("inventory:Update",source)
			end
		else
			if vRP.StoreChest(Passport,"Vault:"..Name..":"..SplitChest[1],Amount,Chests[SplitChest[2]],Slot,Target,true) then
				TriggerClientEvent("inventory:Update",source)
			end
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TAKE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Take(Slot,Amount,Target,Name,Mode)
	local source = source
	local Amount = parseInt(Amount,true)
	local Passport = vRP.Passport(source)
	local SplitChest = splitString(Mode)

	if not Passport then
		return false
	end

	if vRP.TakeChest(Passport,(Name == "Hotel") and Mode..":Hotel:"..Passport or "Vault:"..Name..":"..SplitChest[1],Amount,Slot,Target,true) then
		TriggerClientEvent("inventory:Update",source)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Update(Slot,Target,Amount,Name,Mode)
	local source = source
	local Amount = parseInt(Amount,true)
	local Passport = vRP.Passport(source)
	local SplitChest = splitString(Mode)

	if not Passport then
		return false
	end

	if vRP.UpdateChest(Passport,(Name == "Hotel") and Mode..":Hotel:"..Passport or "Vault:"..Name..":"..SplitChest[1],Slot,Target,Amount,true) then
		TriggerClientEvent("inventory:Update",source)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport)
	if Inside[Passport] then
		vRP.InsidePropertys(Passport,Inside[Passport])
		Inside[Passport] = nil
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSERVERSTART
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	local Additional = 1296000
	local CurrentTimer = os.time()
	local Consult = vRP.Query("propertys/All")
	for _,v in ipairs(Consult) do
		if (v.Tax + Additional) <= CurrentTimer then
			vRP.RemSrvData("Vault:"..v.Name)
			vRP.RemSrvData("Fridge:"..v.Name)
			vRP.Query("propertys/Sell",{ Name = v.Name })

			Wait(100)
		else
			if Propertys[v.Name] then
				Markers[v.Name] = true
				Lock[v.Name] = true
			end
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHARACTERCHOSEN
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("CharacterChosen",function(Passport,source)
	local Increments = {}
	if vRP.Scalar("propertys/Count",{ Passport = Passport }) <= 0 then
		table.insert(Increments,Propertys["Hotel"].Coords)
	else
		local Consult = vRP.Query("propertys/AllUser",{ Passport = Passport })
		if Consult and #Consult > 0 then
			for _,v in pairs(Consult) do
				if Propertys[v.Name] then
					table.insert(Increments,Propertys[v.Name].Coords)
				end
			end
		end
	end

	TriggerClientEvent("spawn:Increment",source,Increments)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:ADICIONAR
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("propertys:Adicionar",function(Property,Selected,Data)
	Objects[Property] = Objects[Property] or vRP.GetSrvData("Probjects:"..Property)
	Objects[Property][Selected] = Data
	vRP.SetSrvData("Probjects:"..Property,Objects[Property],true)
	TriggerClientEvent("propertys:Adicionar",-1,Selected,Data)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:REMOVER
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("propertys:Remover",function(Property,Selected)
	Objects[Property] = Objects[Property] or vRP.GetSrvData("Probjects:"..Property)
	Objects[Property][Selected] = nil
	vRP.SetSrvData("Probjects:"..Property,Objects[Property],true)
	TriggerClientEvent("propertys:Remover",-1,Selected)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- INSIDE
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Inside",function(Passport)
	return Interior[Passport]
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- LOCKED
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Locked",function(Name)
	return Lock[Name]
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- TOGGLELOCK
-----------------------------------------------------------------------------------------------------------------------------------------
exports("ToggleLock",function(Name)
	Lock[Name] = not Lock[Name]
	return Lock[Name]
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- COORDS
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Coords",function(Name)
	return Propertys[Name]
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- MARKERS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Markers()
	return Markers
end