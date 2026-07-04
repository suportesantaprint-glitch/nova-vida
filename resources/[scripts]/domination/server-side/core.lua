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
Tunnel.bindInterface("domination",Lil)
vKEYBOARD = Tunnel.getInterface("keyboard")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Active = {}
local Points = {}
local Multiplier = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- DOMINATION
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand(Command,function(source,Message)
    local Passport = vRP.Passport(source)
    if Passport and vRP.HasGroup(Passport,"Admin",1) then
        local Permissions = {}

        for Permission in pairs(Locations) do
            if vRP.UserDomination(Passport) then
            table.insert(Permissions,Permission)
            end
        end

        table.insert(Permissions,"Finalizar")
        table.sort(Permissions,function(a,b) return a < b end)

        local Keyboard = vKEYBOARD.Instagram(source,Permissions)
        if Keyboard then
            local Permission = Keyboard[1]

            if Permission == "Finalizar" then
                TriggerClientEvent("Notify",source,"Atenção","Dominação cancelada.","amarelo",5000)

                for Index, v in pairs(Active) do
                    if Active[Index] then
                        TriggerClientEvent("Notify",vRP.Source(Index),"Dominação","Um membro da administração finalizou.","amarelo",10000)
                        if Bucket then
                            exports.vrp:Bucket(vRP.Source(Index),"Exit")
                        end
                        Active[Index] = nil
                    end
                end
                TriggerClientEvent("domination:Finish",-1)

                if Select and type(Select) == "table" then
                    for Index, v in pairs(Select) do
                        Select[Index] = nil
                    end
                end
                
                for Index, v in pairs(Multiplier) do
                    Multiplier[Index] = nil
                end

                return
            end

            TriggerClientEvent("Notify",source,Permission,"Dominação iniciada","verde",5000)
            TriggerClientEvent("domination:Start",-1,Permission)
        end
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROGRESS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Progress(Mode)
    local source = source
    local Passport = vRP.Passport(source)
    local Fit = vRP.UserDomination(Passport)
    local Inside = nil

    for Index, v in pairs(Locations) do
        if #(GetEntityCoords(GetPlayerPed(source)) - v.Blip) <= v.SurvivalDistance then
            Inside = Index
        end
    end

    if Mode == "Enter" and Fit then
        Points[Inside] = Points[Inside] or {}
        Active[Passport] = Active[Passport] or {}
        Multiplier[Inside] = Multiplier[Inside] or {}
        Multiplier[Inside][Fit] = Multiplier[Inside][Fit] or 0

        Active[Passport].Permission = Fit
        Active[Passport].Domination = Inside
        Points[Inside][Fit] = Points[Inside][Fit] or 0

        TriggerClientEvent("domination:Update",source,Points[Inside],DominationGoal)

        if Multiplier[Inside][Fit] < MaxPresenceMultiplier then
            Multiplier[Inside][Fit] += PresenceMultiplier
        end

        if Bucket then
            exports.vrp:Bucket(source,"Enter",Bucket)
        end

        elseif Mode == "Exit" and Fit then
        Active[Passport] = nil

        if Multiplier[Inside] and Multiplier[Inside][Fit] then
            Multiplier[Inside][Fit] -= PresenceMultiplier
        end

        if Bucket then
        exports.vrp:Bucket(source,"Exit")
        end
    end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PONTUATION
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Pontuation(Select)
    local source = source
    local Passport = vRP.Passport(source)
    local Permission = Active[Passport].Permission
    if not Permission then return end

    Points[Select] = Points[Select] or {}

    for Group in pairs(Points[Select]) do
        if Group ~= Permission then
            Points[Select][Group] = Points[Select][Group] - 1
        end
    end

    Points[Select][Permission] = (Points[Select][Permission] or 0) + ((Multiplier[Select] and Multiplier[Select][Permission]) or 0) * 1 + 1
    TriggerClientEvent("domination:Update",source,Points[Select],DominationGoal)

    if Points[Select][Permission] >= DominationGoal then
        TriggerClientEvent("Notify",-1,"Dominação","<b>"..Permission.."</b> atingiu <b>"..DominationGoal.."</b> Pontos e ganhou.","verde",10000)

        if Bucket then
            exports.vrp:Bucket(source,"Exit")
        end

        Points[Select] = nil
        Active[Passport] = nil
        Multiplier[Select] = nil
    end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DOMINATION:KILLFEED
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("domination:KillFeed")
AddEventHandler("domination:KillFeed", function(OtherSource)
    local source = source
    local Passport = vRP.Passport(source)
    local OtherPassport = vRP.Passport(OtherSource)

    if not (Passport and OtherPassport) or Passport == OtherPassport then
        return false
    end

    if not (vRP.DoesEntityExist(source) and vRP.DoesEntityExist(OtherSource)) then
        return false
    end

    local Identity = vRP.Identity(Passport)
    local OtherIdentity = vRP.Identity(OtherPassport)

    if not (Identity and OtherIdentity) then
        return false
    end

    local Domination = Active[OtherPassport].Domination
    local Permission = Active[OtherPassport].Permission
    if not (Domination and Permission) then
        return false
    end

    Points[Domination][Permission] += PointsKillFeed

    for Index, v in pairs(Active) do
        if Active[Index] then
            TriggerClientEvent("domination:KillFeed",vRP.Source(Index),OtherIdentity.Name,Identity.Name)
        end
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADTICK
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
    while true do
        local Hours = tonumber(os.date("%H"))
        local Minutes = tonumber(os.date("%M"))
        local Week = os.date("%A")

        for Index, v in pairs(Locations) do
            if Hours == v.Execute.Hour and Minutes == v.Execute.Minute and Week == v.Execute.Week then
                TriggerClientEvent("Notify",-1,"Dominação","Informamos que a disputa no(a) "..v.Name.." iniciou.","verde",15000)
                TriggerClientEvent("domination:Start",-1,Index)
            end
        end

        Wait(30000)
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport,source)
    if Active[Passport] then
        Active[Passport] = nil
    end
end)