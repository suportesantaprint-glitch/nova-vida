-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Entitys = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORYSLOTS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.InventorySlots(Passport)
	local Passport = parseInt(Passport)

	return vRP.DatatableInformation(Passport,"Slots") or Theme.inventory.slots.default
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- REMOVECHARGES
-----------------------------------------------------------------------------------------------------------------------------------------	
function vRP.RemoveCharges(Passport,Item)
	local Consult = vRP.ConsultItem(Passport,Item)

	if not (Consult and Consult.Item and Consult.Slot and Consult.Amount > 0) then
		return false
	end

	if not vRP.TakeItem(Passport,Consult.Item,1,false,Consult.Slot) then
		return false
	end

	if exports.vrp:ItemLoads(Consult.Item) then
		local Slotable = Consult.Slot
		local Name = SplitOne(Consult.Item)
		local Charger = SplitTwo(Consult.Item) - 1

		if Consult.Amount > 1 then
			Slotable = false
		end

		if Charger >= 1 then
			vRP.GiveItem(Passport,Name.."-"..Charger,1,false,Slotable)
		else
			local Empty = exports.vrp:ItemEmpty(Consult.Item)
			if Empty and exports.vrp:ItemExist(Empty) then
				vRP.GenerateItem(Passport,Empty,1,false,Slotable)
			end
		end
	end

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONSULTITEM
-----------------------------------------------------------------------------------------------------------------------------------------	
function vRP.ConsultItem(Passport,Item,Amount)
	local Passport = parseInt(Passport)
	local Amount = parseInt(Amount,true)
	local source = vRP.Source(Passport)

	if source then
		local count = exports.ox_inventory:GetItemCount(source, Item)
		if count >= Amount then
			return { Amount = count, Item = Item, Slot = "1" }
		end
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GETWEIGHT
-----------------------------------------------------------------------------------------------------------------------------------------	
function vRP.GetWeight(Passport,Ignore)
	local Weight = 0
	local Passport = parseInt(Passport)
	local Datatable = vRP.Datatable(Passport)

	if Datatable then
		Datatable.Weight = Datatable.Weight or MinimumWeight
		Weight = Datatable.Weight

		if not Ignore then
			for Index,v in pairs(Groups) do
				if v and v.Backpack then
					local Permission = vRP.HasService(Passport,Index)
					if Permission and v.Backpack[Permission] then
						Weight = Weight + v.Backpack[Permission]
					end
				end
			end

			local Slotable = vRP.CheckSlotable(Passport,"4")
			if Slotable then
				Weight = Weight + exports.vrp:ItemBackpack(Slotable)
			end
		end
	end

	return Weight
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECKWEIGHT
-----------------------------------------------------------------------------------------------------------------------------------------	
function vRP.CheckWeight(Passport,Item,Amount)
	local source = vRP.Source(Passport)
	if source then
		return not exports.ox_inventory:CanCarryItem(source, Item, Amount)
	end
	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPGRADEWEIGHT
-----------------------------------------------------------------------------------------------------------------------------------------	
function vRP.UpgradeWeight(Passport,Amount,Mode)
	local Passport = parseInt(Passport)
	local Datatable = vRP.Datatable(Passport)
	if Datatable then
		Datatable.Weight = Datatable.Weight or MinimumWeight

		if Mode == "+" then
			Datatable.Weight = Datatable.Weight + Amount
		else
			Datatable.Weight = math.max(Datatable.Weight - Amount,MinimumWeight)
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECKSLOTABLE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.CheckSlotable(Passport,Slot)
	local Slot = tostring(Slot)
	local Passport = parseInt(Passport)
	local Inventory = vRP.Inventory(Passport)
	if Inventory and Inventory[Slot] and Inventory[Slot].item and exports.vrp:ItemExist(Inventory[Slot].item) and Inventory[Slot].item and Inventory[Slot].amount >= 1 and not vRP.CheckDamaged(Inventory[Slot].item) then
		return Inventory[Slot].item
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SWAPSLOT	
-----------------------------------------------------------------------------------------------------------------------------------------	
function vRP.SwapSlot(Passport,Slot,Target)
	local Slot = tostring(Slot)
	local Target = tostring(Target)
	local Passport = parseInt(Passport)
	local Inventory = vRP.Inventory(Passport)

	if Inventory[Slot] and Inventory[Target] then
		Inventory[Slot],Inventory[Target] = Inventory[Target],Inventory[Slot]
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORYWEIGHT
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.InventoryWeight(Passport)
	local source = vRP.Source(Passport)
	if source then
		local inv = exports.ox_inventory:GetInventory(source)
		if inv then
			return math.floor(inv.weight / 1000)
		end
	end
	return 0
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECKDAMAGED
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.CheckDamaged(Item)
	local splitTime = SplitTwo(Item)
	local durability = exports.vrp:ItemDurability(Item)

	if durability and splitTime then
		local maxTime = 3600 * durability
		local elapsedTime = os.time() - splitTime
		local remainingPercentage = (maxTime - elapsedTime) / maxTime

		if remainingPercentage <= 0.01 then
			return true
		end
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHESTWEIGHT
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.ChestWeight(Data)
	local Weight = 0

	for _,v in pairs(Data) do
		if exports.vrp:ItemExist(v.item) then
			Weight = Weight + exports.vrp:ItemWeight(v.item) * v.amount
		end
	end

	return Weight
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORYITEMAMOUNT
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.InventoryItemAmount(Passport,Item)
	local ItemSplit = SplitOne(Item)
	local Passport = parseInt(Passport)
	local Inventory = vRP.Inventory(Passport)

	for Slot,v in pairs(Inventory) do
		if ItemSplit == SplitOne(v.item) then
			return { v.amount,v.item,Slot }
		end
	end

	return { 0,"" }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORYFULL
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.InventoryFull(Passport,Item)
	local Passport = parseInt(Passport)
	local Inventory = vRP.Inventory(Passport)

	for _,v in pairs(Inventory) do
		if v.item == Item then
			return true
		end
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- ITEMAMOUNT
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.ItemAmount(Passport,Item)
	local source = vRP.Source(Passport)
	if source then
		return exports.ox_inventory:GetItemCount(source, Item)
	end

	return 0
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- ITEMCHESTAMOUNT
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.ItemChestAmount(Data,Item,Save)
	local Amount = 0
	local ItemSplit = SplitOne(Item)
	local Consult = vRP.GetSrvData(Data,Save)

	for _,v in pairs(Consult) do
		if SplitOne(v.item) == ItemSplit then
			Amount = Amount + v.amount
		end
	end

	return Amount
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GIVEITEM
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.GiveItem(Passport,Item,Amount,Notify,Slot)
	local Amount = parseInt(Amount)
	if Amount <= 0 then
		return false
	end

	local source = vRP.Source(Passport)
	if source then
		return exports.ox_inventory:AddItem(source, Item, Amount)
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GENERATEITEM
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.GenerateItem(Passport,Item,Amount,Notify,Slot)
	return vRP.GiveItem(Passport,Item,Amount,Notify,Slot)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MAXITENS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.MaxItens(Passport,Item,Amount)
	local Item = Item
	if not exports.vrp:ItemExist(Item) then
		return false
	end

	local Passport = parseInt(Passport)
	local Amount = parseInt(Amount,true)
	local MaxAmount = exports.vrp:ItemMaxAmount(Item)
	if not MaxAmount or (vRP.ItemAmount(Passport,Item) + Amount) <= MaxAmount then
		return false
	end

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MAXCHEST
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.MaxChest(Data,Item,Amount,Save)
	local Item = Item
	if not exports.vrp:ItemExist(Item) then
		return false
	end

	local Data = Data
	local Amount = parseInt(Amount)
	local MaxAmount = exports.vrp:ItemMaxAmount(Item)
	if not MaxAmount or (vRP.ItemChestAmount(Data,Item,Save) + Amount) <= MaxAmount then
		return false
	end

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TAKEITEM
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.TakeItem(Passport,Item,Amount,Notify,Slot)
	local Amount = parseInt(Amount,true)
	local source = vRP.Source(Passport)

	if source and Amount > 0 then
		return exports.ox_inventory:RemoveItem(source, Item, Amount)
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLEANSLOT
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.CleanSlot(Passport,Slot)
	local Slot = tostring(Slot)
	local Passport = parseInt(Passport)
	local Inventory = vRP.Inventory(Passport)

	if Inventory[Slot] then
		Inventory[Slot] = nil
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- REMOVEITEM
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.RemoveItem(Passport,Item,Amount,Notify)
	return vRP.TakeItem(Passport, Item, Amount, Notify)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GETSRVDATA
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.GetSrvData(Key,Save)
	if not Entitys[Key] then
		local Consult = vRP.SingleQuery("entitydata/GetData",{ Name = Key })

		Entitys[Key] = {
			Data = Consult and Consult.Information and json.decode(Consult.Information) or {},
			Timer = os.time() + 60,
			Save = Save
		}
	end

	return Entitys[Key].Data
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SETSRVDATA
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.SetSrvData(Key,Data,Save)
	Entitys[Key] = {
		Data = Data,
		Timer = os.time() + 60,
		Save = Save and true or false
	}
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- REMSRVDATA
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.RemSrvData(Key)
	if Entitys[Key] then
		Entitys[Key] = nil
	end

	vRP.Query("entitydata/RemoveData",{ Name = Key })
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SAVESERVER
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("SaveServer",function(Silenced)
	for Index,v in pairs(Entitys) do
		if v.Save then
			vRP.Query("entitydata/SetData",{ Name = Index, Information = json.encode(v.Data) })
		else
			if Silenced and SplitOne(Index,":") == "Trash" then
				for _,v in pairs(v.Data) do
					if v.item and exports.vrp:ItemUnique(v.item) then
						local Unique = SplitUnique(v.item)
						if Unique then
							vRP.RemSrvData(Unique)
						end
					end
				end
			end
		end
	end

	for Passport in pairs(Sources) do
		local Datatable = vRP.Datatable(Passport)
		if Datatable then
			vRP.Query("playerdata/SetData",{ Passport = Passport, Name = "Datatable", Information = json.encode(Datatable) })
		end
	end

	if not Silenced then
		print("O resource ^2vRP^7 salvou os dados.")
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADTICK
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		Wait(60000)

		for Key,v in pairs(Entitys) do
			if os.time() >= v.Timer and v.Save then
				local Save = type(v.Data) == "string" and v.Data or json.encode(v.Data)
				vRP.Query("entitydata/SetData",{ Name = Key, Information = Save })
				Entitys[Key] = nil
			end
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVUPDATE
-----------------------------------------------------------------------------------------------------------------------------------------
function tvRP.invUpdate(Slot,Target,Amount)
	local source = source
	local Amount = parseInt(Amount)
	local Passport = vRP.Passport(source)
	if Passport and Amount > 0 then
		local Item = nil
		local Returned = true
		local Slot = tostring(Slot)
		local Target = tostring(Target)
		local Inventory = vRP.Inventory(Passport)

		if Inventory[Slot] then
			Item = Inventory[Slot].item

			if Inventory[Target] then
				if Inventory[Slot] and Inventory[Target] then
					if Item == Inventory[Target].item then
						if Inventory[Slot].amount >= Amount then
							Inventory[Slot].amount = Inventory[Slot].amount - Amount
							Inventory[Target].amount = Inventory[Target].amount + Amount

							if Inventory[Slot].amount <= 0 then
								Inventory[Slot] = nil
							end

							Returned = false
						end
					else
						local Unique = SplitOne(Item)
						local Splice = splitString(Inventory[Target].item)
						local ItemRepair = exports.vrp:ItemRepair(Inventory[Target].item)
						local ItemFishing = exports.vrp:ItemFishing(Inventory[Target].item)

						if Unique == "gsrkit" and exports.vrp:ItemSerial(Splice[1]) then
							if vRP.TakeItem(Passport,Item,1,false,Slot) then
								if Splice[4] then
									TriggerClientEvent("inventory:Notify",source,"Sucesso","Propriedade do passaporte <b>"..Splice[4].."</b>","verde")
								else
									TriggerClientEvent("inventory:Notify",source,"Aviso","Serial não encontrado.","amarelo")
								end
							end
						elseif Unique == "WEAPON_SWITCHBLADE" and not vRP.CheckDamaged(Item) and ItemFishing then
							local Temporary = Inventory[Target].amount
							if vRP.TakeItem(Passport,Inventory[Target].item,Temporary,false,Target) then
								vRP.GenerateItem(Passport,"fishfillet",Temporary * ItemFishing)
							end
						elseif vRP.CheckDamaged(Inventory[Target].item) and ItemRepair and Inventory[Target].amount == 1 and ItemRepair == Unique then
							if exports.vrp:ItemTypeCheck(Inventory[Target].item,"Armamento") and parseInt(Splice[3]) <= 0 then
								TriggerClientEvent("inventory:Notify",source,"Aviso","Armamento não pode ser reparado.","amarelo")
							else
								if vRP.TakeItem(Passport,Item,1,false,Slot) then
									local CurrentTime = os.time() - 1
									if exports.vrp:ItemTypeCheck(Inventory[Target].item, "Armamento") then
										local Serial = Splice[4] and "-"..(Passport or "")
										Inventory[Target].item = Splice[1].."-"..CurrentTime.."-"..parseInt(Splice[3] - 1)..Serial
									else
										if exports.vrp:ItemUnique(Splice[1]) then
											Inventory[Target].item = Splice[1].."-"..CurrentTime.."-"..Splice[3]
										else
											Inventory[Target].item = Splice[1].."-"..CurrentTime
										end
									end
								end
							end
						else
							local Temp = Inventory[Slot]
							Inventory[Slot] = Inventory[Target]
							Inventory[Target] = Temp

							Returned = false
						end
					end
				end
			else
				if Inventory[Slot] and Inventory[Slot].amount >= Amount then
					Inventory[Target] = { item = Item, amount = Amount }
					Inventory[Slot].amount = Inventory[Slot].amount - Amount

					if Inventory[Slot].amount <= 0 then
						Inventory[Slot] = nil
					end

					Returned = false
				end
			end
		end

		if Item and (Returned or Target == "4" or Slot == "4") then
			TriggerClientEvent("inventory:Update",source)

			local Skinshop = exports.vrp:ItemSkinshop(Item)
			if Target == "4" and Skinshop then
				TriggerClientEvent("skinshop:Backpack",source,Skinshop)
			elseif Slot == "4" and Skinshop then
				TriggerClientEvent("skinshop:BackpackRemove",source)
			end
		end

		return true
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TRYCHEST
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.TakeChest(Passport,Data,Amount,Slot,Target,Save)
	local Returned = true
	local Amount = parseInt(Amount)
	local Passport = parseInt(Passport)

	if Amount <= 0 then
		return Returned
	end

	local Slot = tostring(Slot)
	local Consult = vRP.GetSrvData(Data,Save)

	if not Consult[Slot] then
		return Returned
	end

	local source = vRP.Source(Passport)
	local Item = Consult[Slot].item
	local Animation = exports.vrp:ItemAnim(Item)

	if vRP.MaxItens(Passport,Item,Amount) then
		TriggerClientEvent("inventory:Notify",source,"Atenção","Limite atingido.","vermelho")
		return Returned
	end

	if not vRP.CheckWeight(Passport,Item,Amount) then
		return Returned
	end

	local Target = tostring(Target)
	local Inv = vRP.Inventory(Passport)

	if Inv[Target] then
		if Inv[Target].item == Item and Consult[Slot].amount >= Amount then
			exports["discord"]:Embed("Chest","**[REF]:** "..Data.."\n**[MODO]:** Retirou\n**[PASSAPORTE]:** "..Passport.."\n**[ITEM]:** "..Amount.."x "..Item.."\n**[DATA & HORA]:** "..os.date("%d/%m/%Y").." às "..os.date("%H:%M"))

			Inv[Target].amount = Inv[Target].amount + Amount
			Consult[Slot].amount = Consult[Slot].amount - Amount

			if Consult[Slot].amount <= 0 then
				Consult[Slot] = nil
			end

			Returned = false
		end
	else
		if Consult[Slot].amount >= Amount then
			exports["discord"]:Embed("Chest","**[REF]:** "..Data.."\n**[MODO]:** Retirou\n**[PASSAPORTE]:** "..Passport.."\n**[ITEM]:** "..Amount.."x "..Item.."\n**[DATA & HORA]:** "..os.date("%d/%m/%Y").." às "..os.date("%H:%M"))

			Inv[Target] = { item = Item, amount = Amount }
			Consult[Slot].amount = Consult[Slot].amount - Amount

			if Consult[Slot].amount <= 0 then
				Consult[Slot] = nil
			end
			
			if Animation then
				vRPC.PersistentBlock(source,Item,Animation)
			end

			if exports.vrp:ItemTypeCheck(Item,"Armamento") and vRP.ConsultItem(Passport,Item) then
				TriggerClientEvent("inventory:CreateWeapon",source,Item)
			end

			TriggerClientEvent("inventory:Update",source)

			if Target == "4" then
				local Skinshop = exports.vrp:ItemSkinshop(Item)
				if Skinshop then
					TriggerClientEvent("skinshop:Backpack",source,Skinshop)
				end
			end

			Returned = false
		end
	end

	return Returned
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLEANSLOTCHEST
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.CleanSlotChest(Data,Slot,Save)
	local Consult = vRP.GetSrvData(Data,Save)

	if Consult and Consult[Slot] then
		Consult[Slot] = nil
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- STORECHEST
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.StoreChest(Passport,Data,Amount,Weight,Slot,Target,Save,Max)
	local Returned = true
	local Amount = parseInt(Amount)
	local Passport = parseInt(Passport)

	if Amount <= 0 then
		return Returned
	end

	local Slot = tostring(Slot)
	local Inv = vRP.Inventory(Passport)

	if Inv[Slot] then
		local Item = Inv[Slot].item
		if not Max or not vRP.MaxChest(Data,Item,Amount,Save) then
			local Target = tostring(Target)
			local source = vRP.Source(Passport)
			local Consult = vRP.GetSrvData(Data,Save)

			if (vRP.ChestWeight(Consult) + (exports.vrp:ItemWeight(Item) * Amount)) <= Weight then
				local Animation = exports.vrp:ItemAnim(Item)
				if Consult[Target] and Inv[Slot] then
					if Item == Consult[Target].item and Inv[Slot].amount >= Amount then
						exports["discord"]:Embed("Chest","**[REF]:** "..Data.."\n**[MODO]:** Guardou\n**[PASSAPORTE]:** "..Passport.."\n**[ITEM]:** "..Amount.."x "..Item.."\n**[DATA & HORA]:** "..os.date("%d/%m/%Y").." às "..os.date("%H:%M"))

						Consult[Target].amount = Consult[Target].amount + Amount
						Inv[Slot].amount = Inv[Slot].amount - Amount

						if Inv[Slot].amount <= 0 then
							Inv[Slot] = nil

							if Slot == "4" then
								TriggerClientEvent("inventory:Update",source)

								local Skinshop = exports.vrp:ItemSkinshop(Item)
								if Skinshop then
									TriggerClientEvent("skinshop:BackpackRemove",source)
								end
							end

							if Animation and not vRP.ConsultItem(Passport,Item) then
								vRPC.PersistentNone(source,Item)
							end

							if exports.vrp:ItemTypeCheck(Item,"Armamento") or exports.vrp:ItemTypeCheck(Item,"Arremesso") then
								TriggerClientEvent("inventory:verifyWeapon",source,Item)
							end

							local Execute = exports.vrp:ItemExecute(Item)
							if Execute and Execute.Event and Execute.Type and not vRP.ConsultItem(Passport,Item) then
								if Execute.Type == "Client" then
									TriggerClientEvent(Execute.Event,source)
								else
									TriggerEvent(Execute.Event,source,Passport)
								end
							end
						end

						Returned = false
					end
				else
					if Inv[Slot] and Inv[Slot].amount >= Amount then
						exports["discord"]:Embed("Chest","**[REF]:** "..Data.."\n**[MODO]:** Guardou\n**[PASSAPORTE]:** "..Passport.."\n**[ITEM]:** "..Amount.."x "..Item.."\n**[DATA & HORA]:** "..os.date("%d/%m/%Y").." às "..os.date("%H:%M"))

						Consult[Target] = { item = Item, amount = Amount }
						Inv[Slot].amount = Inv[Slot].amount - Amount

						if Inv[Slot].amount <= 0 then
							Inv[Slot] = nil

							if Slot == "4" then
								TriggerClientEvent("inventory:Update",source)

								local Skinshop = exports.vrp:ItemSkinshop(Item)
								if Skinshop then
									TriggerClientEvent("skinshop:BackpackRemove",source)
								end
							end

							if Animation and not vRP.ConsultItem(Passport,Item) then
								vRPC.PersistentNone(source,Item)
							end

							if exports.vrp:ItemTypeCheck(Item,"Armamento") or exports.vrp:ItemTypeCheck(Item,"Arremesso") then
								TriggerClientEvent("inventory:verifyWeapon",source,Item)
							end

							local Execute = exports.vrp:ItemExecute(Item)
							if Execute and Execute.Event and Execute.Type and not vRP.ConsultItem(Passport,Item) then
								if Execute.Type == "Client" then
									TriggerClientEvent(Execute.Event,source)
								else
									TriggerEvent(Execute.Event,source,Passport)
								end
							end
						end

						Returned = false
					end
				end
			else
				TriggerClientEvent("inventory:Notify",source,"Atenção","Limite de peso atingido.","vermelho")
			end
		end
	end

	return Returned
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATECHEST
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.UpdateChest(Passport,Data,Slot,Target,Amount,Save)
	local Returned = true
	local Slot = tostring(Slot)
	local Amount = parseInt(Amount,true)
	local Consult = vRP.GetSrvData(Data,Save)

	if Consult[Slot] then
		local Target = tostring(Target)
		if Consult[Target] and Consult[Slot].item == Consult[Target].item then
			if Consult[Slot].amount >= Amount then
				Consult[Slot].amount = Consult[Slot].amount - Amount

				if Consult[Slot].amount <= 0 then
					Consult[Slot] = nil
				end

				Consult[Target].amount = Consult[Target].amount + Amount

				Returned = false
			end
		elseif Consult[Target] then
			local Temp = Consult[Slot]
			Consult[Slot] = Consult[Target]
			Consult[Target] = Temp

			Returned = false
		else
			if Consult[Slot].amount >= Amount then
				Consult[Target] = { item = Consult[Slot].item, amount = Amount }
				Consult[Slot].amount = Consult[Slot].amount - Amount

				if Consult[Slot].amount <= 0 then
					Consult[Slot] = nil
				end

				Returned = false
			end
		end
	end

	return Returned
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- ARRESTITENS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.ArrestItens(Passport)
	local itemsToRemove = {}
	local Passport = parseInt(Passport)
	local Inventory = vRP.Inventory(Passport)

	for _,v in pairs(Inventory) do
		if exports.vrp:ItemArrest(v.item) then
			table.insert(itemsToRemove,{ item = v.item, amount = v.amount })
		end
	end

	for _,v in pairs(itemsToRemove) do
		vRP.RemoveItem(Passport,v.item,v.amount,true)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MOUNTCONTAINER
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.MountContainer(Passport,Datatable,Table,Multiplier,Save,Percentage,Dollars)
	local Itens = {}
	local Exists = {}
	local Passport = Passport
	local Multiplier = Multiplier or 1

	if not Percentage or math.random(1000) <= Percentage then
		for Number = 0,Multiplier do
			local Rand = RandPercentage(Table)
			if not Exists[Rand.Item] then
				Exists[Rand.Item] = true

				Itens[tostring(Number)] = {
					item = vRP.SortNameItem(Passport,Rand.Item),
					amount = math.random(Rand.Min,Rand.Max)
				}
			end
		end

		if Dollars then
			local Amount = CountTable(Itens)
			Itens[tostring(Amount + 1)] = {
				item = vRP.SortNameItem(Passport,Dollars.Item),
				amount = parseInt(Dollars.Amount)
			}
		end
	end

	vRP.SetSrvData(Datatable,Itens,Save or false)

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SORTNAMEITEM
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.SortNameItem(Passport,Item)
	local NameItem = Item
	local Passport = Passport
	local CurrentTime = os.time() - 1

	if exports.vrp:ItemUnique(Item) then
		local Hash = vRP.GenerateHash(Item)

		if Boxes[Item] then
			local multiplierMin = Boxes[Item].Multiplier.Min
			local multiplierMax = Boxes[Item].Multiplier.Max
			vRP.MountContainer(Passport,Item..":"..Hash,Boxes[Item].List,math.random(multiplierMin,multiplierMax),true)
		end

		NameItem = Item.."-"..CurrentTime.."-"..Hash
	elseif exports.vrp:ItemDurability(Item) then
		if exports.vrp:ItemTypeCheck(Item,"Armamento") then
			NameItem = Item.."-"..CurrentTime.."-"..MaxRepair.."-"..Passport
		else
			NameItem = Item.."-"..CurrentTime
		end
	elseif exports.vrp:ItemLoads(Item) then
		NameItem = Item.."-"..exports.vrp:ItemLoads(Item)
	elseif exports.vrp:ItemNamed(Item) then
		NameItem = Item.."-"..Passport
	end

	return NameItem
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CALLPOLICE
-----------------------------------------------------------------------------------------------------------------------------------------
exports("CallPolice",function(Table)
	if Table.Percentage and math.random(1000) < Table.Percentage then
		return false
	end

	local source = Table.Source
	local passport = Table.Passport

	if Table.Wanted then
		TriggerEvent("Wanted",source,passport,Table.Wanted)
	end

	if Table.Marker then
		local marker = type(Table.Marker) == "number" and Table.Marker or false
		exports["markers"]:Enter(source,Table.Name,1,passport,marker)
	end

	if Table.Notify then
		TriggerClientEvent("Notify",source,"Departamento Policial","As autoridades foram acionadas.","policia",5000)
	end

	local service = vRP.NumPermission(Table.Permission)
	local coords = Table.Coords or vRP.GetEntityCoords(source)
	for _,officer in pairs(service) do
		async(function()
			vRPC.PlaySound(officer,"ATM_WINDOW","HUD_FRONTEND_DEFAULT_SOUNDSET")

			local notification = {
				code = Table.Code or 20,
				title = Table.Name,
				x = coords.x,
				y = coords.y,
				z = coords.z,
				vehicle = Table.Vehicle,
				color = Table.Color or 44
			}

			TriggerClientEvent("NotifyPush",officer,notification)
		end)
	end
end)