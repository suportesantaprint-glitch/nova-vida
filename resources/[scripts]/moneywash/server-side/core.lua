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
Tunnel.bindInterface("moneywash",Lil)
vKEYBOARD = Tunnel.getInterface("keyboard")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Cooldown = 0
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATEOBJECTS
-----------------------------------------------------------------------------------------------------------------------------------------
exports("UpdateObjects",function(OldPassport,NewPassport)
	local Moneywash = vRP.GetSrvData("MoneyWash",true) or {}
	
	for Number, Machines in pairs(Moneywash) do
		if Machines.Passport and Machines.Passport == OldPassport then
			Moneywash[Number].Passport = NewPassport
			TriggerClientEvent("objects:Update",-1,Number,NewPassport)
		end
	end
	
	vRP.SetSrvData("MoneyWash",Moneywash,true)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADCOOLDOWN
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
    while true do
        if os.time() >= Cooldown then
            Cooldown = os.time() + 10

            local Moneywash = vRP.GetSrvData("MoneyWash",true) or {}
            for Number, Machines in pairs(Moneywash) do
                if Machines.Timer and Machines.Timer > os.time() 
                   and Machines.Bleach and Machines.Bleach > os.time() 
                   and Machines.Money > 0 then
                    
                    local Efficiency = 0.05
                    if Machines.Bleach > os.time() then
                        Efficiency = Efficiency + BleachPercentage
                    end
                    
                    local Amount = math.floor(Machines.Money * Efficiency)
                    if Amount > 0 then
                        Moneywash[Number].Money = Machines.Money - Amount
                        Moneywash[Number].Washed = (Machines.Washed or 0) + Amount
                        Moneywash[Number].Last = os.time() + 300
                    end
                end
            end

            vRP.SetSrvData("MoneyWash",Moneywash,true)
            TriggerClientEvent("moneywash:Table",-1,Moneywash)
        end
        Wait(1000)
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- INFORMATION
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Information(Number)
    local Moneywash = vRP.GetSrvData("MoneyWash",true) or {}
    return Moneywash[Number] or false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- OSTIME
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.OsTime()
    return os.time()
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- WASH
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Wash", function(Passport, Item, Hash, Coords, Route)
    local Moneywash = vRP.GetSrvData("MoneyWash", true) or {}

    repeat
        Number = GenerateString("DDLLDDLL")
    until not Moneywash[Number]

    Moneywash[Number] = { Route = Route, Coords = Coords, Hash = Hash, Item = Item, Money = 0, Washed = 0, Timer = 0, Bleach = 0, Last = 0, Passport = Passport, Password = nil }

    vRP.SetSrvData("MoneyWash",Moneywash,true)
    TriggerClientEvent("moneywash:New",-1,Number,Moneywash[Number])
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- MONEYWASH:ADD
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("moneywash:Add")
AddEventHandler("moneywash:Add", function(Selected)
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport then return end

    local Moneywash = vRP.GetSrvData("MoneyWash",true) or {}

    if Moneywash[Selected].Timer <= os.time() then
        TriggerClientEvent("Notify",source,"Aviso","Adicione uma bateria primeiro.","vermelho",5000)
        return
    end

    local Keyboard = vKEYBOARD.Primary(source, "Quantidade:")
    if Keyboard then
        TriggerClientEvent("dynamic:Close",source)
        local Quantity = parseInt(Keyboard[1])
        if Quantity <= 0 then return end

        if vRP.TakeItem(Passport,"dirtydollar",Quantity,true) then
            Moneywash[Selected].Money = Moneywash[Selected].Money + Quantity
            vRP.SetSrvData("MoneyWash",Moneywash,true)
            TriggerClientEvent("moneywash:Update",-1,Selected,Moneywash[Selected])
            TriggerClientEvent("Notify",source,"Sucesso","Dinheiro adicionado.","verde",5000)
        end
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- MONEYWASH:MONEY
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("moneywash:Money")
AddEventHandler("moneywash:Money", function(Selected)
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport then return end

    local Moneywash = vRP.GetSrvData("MoneyWash",true) or {}
    if not Moneywash[Selected] then return end

    local Amount = Moneywash[Selected].Money or 0
    if Amount > 0 then
        vRP.GenerateItem(Passport,"wetdollar",Amount,true)
        Moneywash[Selected].Money = 0
        vRP.SetSrvData("MoneyWash",Moneywash,true)
        TriggerClientEvent("dynamic:Close",source)
        TriggerClientEvent("moneywash:Update",-1,Selected,Moneywash[Selected])
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- MONEYWASH:WASHED
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("moneywash:Washed")
AddEventHandler("moneywash:Washed", function(Selected)
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport then return end

    local Moneywash = vRP.GetSrvData("MoneyWash",true) or {}
    if not Moneywash[Selected] then return end

    local Amount = Moneywash[Selected].Washed or 0
    if Amount > 0 then
        vRP.GenerateItem(Passport,"dollar",Amount,true)
        Moneywash[Selected].Washed = 0
        vRP.SetSrvData("MoneyWash",Moneywash,true)
        TriggerClientEvent("dynamic:Close",source)
        TriggerClientEvent("moneywash:Update",-1,Selected,Moneywash[Selected])
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- MONEYWASH:BATTERY
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("moneywash:Battery")
AddEventHandler("moneywash:Battery", function(Selected)
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport then return end

    local Moneywash = vRP.GetSrvData("MoneyWash",true) or {}
    if not Moneywash[Selected] then return end

    if Moneywash[Selected].Timer > os.time() then
        TriggerClientEvent("Notify", source, "Aviso", "Já tem uma bateria ativa.", "amarelo", 5000)
        return
    end

    if vRP.TakeItem(Passport,"washbattery",1,true) then
        Moneywash[Selected].Timer = os.time() + BatteryDuration
        vRP.SetSrvData("MoneyWash",Moneywash,true)
        TriggerClientEvent("dynamic:Close",source)
        TriggerClientEvent("Notify",source,"Sucesso","Bateria colocada.","verde",5000)
        TriggerClientEvent("moneywash:Update",-1,Selected,Moneywash[Selected])
    else
        TriggerClientEvent("Notify",source,"Aviso","Você precisa de 1x Bateria 75Ah","amarelo",5000)
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- MONEYWASH:BLEACH
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("moneywash:Bleach")
AddEventHandler("moneywash:Bleach", function(Selected)
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport then return end

    local Moneywash = vRP.GetSrvData("MoneyWash",true) or {}
    if not Moneywash[Selected] then return end

    if Moneywash[Selected].Bleach > os.time() then
        TriggerClientEvent("Notify", source, "Aviso", "Já tem alvejante ativo.", "amarelo", 5000)
        return
    end

    if vRP.TakeItem(Passport,"washbleach",1,true) then
        Moneywash[Selected].Bleach = os.time() + BleachDuration
        vRP.SetSrvData("MoneyWash",Moneywash,true)
        TriggerClientEvent("dynamic:Close",source)
        TriggerClientEvent("Notify",source,"Sucesso","Alvejante adicionado","verde",5000)
        TriggerClientEvent("moneywash:Update",-1,Selected,Moneywash[Selected])
    else
        TriggerClientEvent("Notify",source,"Aviso","Você precisa de 1x Alvejante","amarelo",5000)
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- MONEYWASH:PASSWORD
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("moneywash:Password")
AddEventHandler("moneywash:Password",function(Selected)
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport then return end

    local Moneywash = vRP.GetSrvData("MoneyWash",true) or {}
    
    local Keyboard = vKEYBOARD.Password(source,"Senha")
    if Keyboard then
        TriggerClientEvent("dynamic:Close",source)
        local Password = Keyboard[1]
        Moneywash[Selected].Password = Password
        vRP.SetSrvData("MoneyWash",Moneywash,true)
        TriggerClientEvent("Notify",source,"Sucesso","Palavra chave atualizada","verde",5000)
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- MONEYWASH:STOREOBJECTS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("moneywash:StoreObjects")
AddEventHandler("moneywash:StoreObjects", function(Selected)
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport then return end

    local Moneywash = vRP.GetSrvData("MoneyWash",true) or {}
    if not Moneywash[Selected] then return end

    local Item = Moneywash[Selected].Item

    Moneywash[Selected] = nil
    vRP.SetSrvData("MoneyWash",Moneywash,true)
    TriggerClientEvent("moneywash:Remove",-1,Selected)

    if Item then
        vRP.GenerateItem(Passport,Item,1,true)
    end

    TriggerClientEvent("Notify",source,"Sucesso","Máquina recolhida.","verde",5000)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Connect",function(Passport,source)
  local Moneywash = vRP.GetSrvData("MoneyWash",true) or {}
	TriggerClientEvent("moneywash:Table",-1,Moneywash)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport,source)
	if Passport then
		  Passport = nil
	  end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SAVESERVER
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("SaveServer",function(Silenced)
  local Moneywash = vRP.GetSrvData("MoneyWash",true) or {}
	vRP.Query("entitydata/SetData",{ Name = "MoneyWash", Information = json.encode(Moneywash) })

	if not Silenced then
		print("O resource ^2Moneywash^7 salvou os dados.")
	end
end)