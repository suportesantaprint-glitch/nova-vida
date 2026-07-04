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
Tunnel.bindInterface("painel",Lil)
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Division = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- PAINEL:OPEN
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("painel:Open")
AddEventHandler("painel:Open",function(Group)
    local source = source
    local Passport = vRP.Passport(source)
    
    if Passport and vRP.HasPermission(Passport,Group) then
        Division[Passport] = Group
    else
        Division[Passport] = nil
    end
    
    TriggerClientEvent("dynamic:Close",source)
    TriggerClientEvent("painel:Opened",source)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DEPARTMENT
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Department()
    local source = source
    local Passport = vRP.Passport(source)
    return Passport and Division[Passport] or false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Player()
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    local GroupInfo = Groups[Group] or {}
    local Hierarchy = vRP.Hierarchy(Group)
    local Owner = (Level == 1)
    

    local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
    local Permission = Consult[tostring(Level)] or {}

    local Permissions = {
        Management = {
            View = Permission.Management and Permission.Management.View or Owner,
            Create = Permission.Management and Permission.Management.Create or Owner,
            Edit = Permission.Management and Permission.Management.Edit or Owner,
            Dismiss = Permission.Management and Permission.Management.Dismiss or Owner
        },
        Announcements = {
            Create = Permission.Announcements and Permission.Announcements.Create or Owner,
            Edit = Permission.Announcements and Permission.Announcements.Edit or Owner,
            Delete = Permission.Announcements and Permission.Announcements.Delete or Owner
        },
        Tags = {
            View = Permission.Tags and Permission.Tags.View or Owner,
            Create = Permission.Tags and Permission.Tags.Create or Owner,
            Assign = Permission.Tags and Permission.Tags.Assign or Owner,
            Edit = Permission.Tags and Permission.Tags.Edit or Owner,
            Delete = Permission.Tags and Permission.Tags.Delete or Owner
        },
        Bank = {
            View = Permission.Bank and Permission.Bank.View or Owner,
            Deposit = Permission.Bank and Permission.Bank.Deposit or Owner,
            Withdraw = Permission.Bank and Permission.Bank.Withdraw or Owner,
            Transfer = Permission.Bank and Permission.Bank.Transfer or Owner
        },
        Goals = {
            MyGoals = Permission.Goals and Permission.Goals.MyGoals or Owner,
            All = Permission.Goals and Permission.Goals.All or Owner,
            Edit = Permission.Goals and Permission.Goals.Edit or Owner
        },
        Perks = Permission.Perks or Owner
    }
    
    return {
        Group = Group,
        Disabled = Config.Disabled[Group] or {},
        Player = {
            Name = vRP.FullName(Passport),
            Level = Level,
            Passport = Passport
        },
        GroupData = {
            Name = GroupInfo.Name or Group,
            Hierarchy = Hierarchy
        },
        Permissions = Permissions
    }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MEMBERS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Members(Ranking)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return false
    end
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level then
        return false
    end
    
    if Level ~= 1 and Group ~= "Admin" then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if LevelPerms and LevelPerms.Management then
            if not LevelPerms.Management.View then
                TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
                return false
            end
        elseif Level ~= 1 then
            TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
            return false
        end
    end
    
    local Members = {}
    local Groups = vRP.DataGroups(Group)
    local Service = vRP.NumPermission(Group)
    
    local Tags = exports.oxmysql:query_async("SELECT Image, Name, Members FROM painel_creative_tags WHERE Permission = ?",{ Group }) or {}
    for _, Tag in ipairs(Tags) do
        Tag.Decoded = Tag.Members and json.decode(Tag.Members) or {}
    end
    
    for Target in pairs(Groups) do
        local Identity = vRP.Identity(Target)
        local Hierarchy = vRP.HasPermission(Target,Group)
        
        if Identity and Hierarchy then
            local Assigned = {}
            for _, Tag in ipairs(Tags) do
                for _, Number in ipairs(Tag.Decoded) do
                    if tonumber(Number) == tonumber(Target) then
                        Assigned[#Assigned + 1] = { Image = Tag.Image, Name = Tag.Name }
                        break
                    end
                end
            end
            
            local Played = vRP.Playing(Target, Group) or 0
            local Hours = math.floor(Played / 3600)
            local Minutes = math.floor((Played % 3600) / 60)
            local TimerLabel = Hours > 0 and string.format("%dh %dmin",Hours,Minutes) or string.format("%dmin",Minutes)
            
            local Status = vRP.Source(Target) and ("Ativo a "..TimerLabel) or ("Inativo a "..TimerLabel)
            
            Members[#Members + 1] = {
                Passport = Target,
                Name = vRP.FullName(Target),
                Hierarchy = Hierarchy,
                Tags = Assigned,
                Service = Service[Target] and 1 or 0,
                Hours = Played,
                Status = Status
            }
        end
    end
    
    if Ranking then
        table.sort(Members,function(a,b)
            return a.Hours > b.Hours
        end)
    end
    
    return { Members = Members, Max = vRP.Permissions(Group,"Members") }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TAGS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Tags()
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    if Level ~= 1 and Group ~= "Admin" then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if LevelPerms and LevelPerms.Tags then
            if not LevelPerms.Tags.View then
                TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
                return false
            end
        elseif Level ~= 1 then
            TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
            return false
        end
    end
    
    local Consult = exports.oxmysql:query_async("SELECT * FROM painel_creative_tags WHERE LOWER(Permission) = LOWER(?)",{ Group }) or {}
    local Tags = {}
    
    for _, Row in ipairs(Consult) do
        Tags[#Tags + 1] = {
            Id = Row.id,
            Image = Row.Image,
            Members = json.decode(Row.Members) or {},
            Name = Row.Name
        }
    end
    
    return Tags
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GETTAG
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.GetTag(Identifier)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Identifier then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    local Consult = exports.oxmysql:single_async("SELECT id, Image, Name, Members FROM painel_creative_tags WHERE Id = ? AND LOWER(Permission) = LOWER(?)",{ Identifier, Group })
    if not Consult then
        return false
    end
    
    local Members = {}
    local List = json.decode(Consult.Members) or {}
    for _, PassportID in ipairs(List) do
        Members[#Members + 1] = { Passport = PassportID, Name = vRP.FullName(PassportID) }
    end
    
    return {
        Id = Consult.id,
        Image = Consult.Image,
        Name = Consult.Name,
        Members = Members
    }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CREATETAG
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.CreateTag(Data)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Data then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if LevelPerms and LevelPerms.Tags then
            Allowed = LevelPerms.Tags.Create
        end
    end
    
    if not Allowed then
        TriggerClientEvent("painel:Notify",source,"Atencao", "Você não possui permissão.","amarelo")
        return false
    end
    
    local Count = exports.oxmysql:scalar_async("SELECT COUNT(*) FROM painel_creative_tags WHERE Permission = ?",{ Group }) or 0
    local Max = vRP.Permissions(Group,"Tags") or 0
    
    if Count >= Max then
        TriggerClientEvent("painel:Notify",source,"Atencao","Limite de tags atingido.","amarelo")
        return true
    end
    
    exports.oxmysql:insert_async("INSERT INTO painel_creative_tags (Name, Image, Permission) VALUES (?, ?, ?)",{ Data.Name, Data.Image, Group })
    TriggerClientEvent("painel:Notify",source,"Sucesso","Tag criada.","verde")
    
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATETAG
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.UpdateTag(Data)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Data or not Data.Id then
        return false
    end
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if LevelPerms and LevelPerms.Tags then
            Allowed = LevelPerms.Tags.Edit
        end
    end
    
    if not Allowed then
        TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    exports.oxmysql:execute_async("UPDATE painel_creative_tags SET Name = ?, Image = ? WHERE Id = ? AND Permission = ?",{ Data.Name, Data.Image, Data.Id, Group })
    TriggerClientEvent("painel:Notify",source,"Sucesso","Tag atualizada.","verde")
    
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- ASSIGNTAG
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.AssignTag(Data)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Data or not Data.Id or not Data.Passport then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1 or Group == "Admin")
    if not Allowed then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if LevelPerms and LevelPerms.Tags then
            Allowed = LevelPerms.Tags.Assign
        end
    end
    
    if not Allowed then
        TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Consult = exports.oxmysql:single_async("SELECT id, Image, Name, Members FROM painel_creative_tags WHERE Id = ? AND LOWER(Permission) = LOWER(?)", { Data.Id, Group })
    if not Consult then
        return false
    end
    
    local Members = json.decode(Consult.Members) or {}
    for _, Member in ipairs(Members) do
        if Member == Data.Passport then
            return false
        end
    end
    
    Members[#Members + 1] = Data.Passport
    exports.oxmysql:execute_async("UPDATE painel_creative_tags SET Members = ? WHERE Id = ?",{ json.encode(Members), Data.Id })
    
    TriggerClientEvent("painel:Notify",source,"Sucesso","Tag atribuida.","verde")
    
    local TargetSource = vRP.Source(Data.Passport)
    if TargetSource then
        TriggerClientEvent("Notify",TargetSource,Consult.Name,"Você recebeu uma tag.","verde")
    end
    
    return { Passport = Data.Passport, Name = vRP.FullName(Data.Passport) }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- REMOVETAG
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.RemoveTag(Data)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Data or not Data.Id or not Data.Passport then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1 or Group == "Admin")
    if not Allowed then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if LevelPerms and LevelPerms.Tags then
            Allowed = LevelPerms.Tags.Assign
        end
    end
    
    if not Allowed then
        TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Consult = exports.oxmysql:single_async("SELECT id, Image, Name, Members FROM painel_creative_tags WHERE Id = ? AND LOWER(Permission) = LOWER(?)",{ Data.Id, Group })
    if not Consult then
        return false
    end
    
    local Members = json.decode(Consult.Members) or {}
    for Index, Member in ipairs(Members) do
        if Member == Data.Passport then
            table.remove(Members, Index)
            break
        end
    end
    
    exports.oxmysql:execute_async("UPDATE painel_creative_tags SET Members = ? WHERE Id = ?",{ json.encode(Members), Data.Id })
    TriggerClientEvent("painel:Notify",source,"Sucesso","Tag removida.","verde")
    
    return { Passport = Data.Passport }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DESTROYTAG
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.DestroyTag(Identifier)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Identifier then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if LevelPerms and LevelPerms.Tags then
            Allowed = LevelPerms.Tags.Delete
        end
    end
    
    if not Allowed then
        TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    exports.oxmysql:execute_async("DELETE FROM painel_creative_tags WHERE id = ? AND Permission = ?",{ Identifier, Group })
    TriggerClientEvent("painel:Notify",source,"Sucesso","Tag removida.","verde")
    
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVITE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Invite(Target)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return false
    end
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level then
        return false
    end
    
    if Level ~= 1 then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if not (LevelPerms and LevelPerms.Management and LevelPerms.Management.Create) then
            TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
            return false
        end
    end
    
    Target = parseInt(Target)
    if Target <= 0 or Target == Passport then
        return true
    end
    
    if not vRP.GetUserType(Target, "Work") then
        local TargetSource = vRP.Source(Target)
        if TargetSource and vRP.Request(TargetSource,"Grupos","Você foi convidado(a) para participar do grupo <b>" .. Group .. "</b>, deseja entrar?") then
            vRP.SetPermission(Target, Group)
            TriggerClientEvent("painel:Notify",source,"Sucesso","Passaporte adicionado.","verde")
        end
    end
    
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- HIERARCHY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Hierarchy(Data)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Data or not Data.Passport or not Data.Mode then
        return false
    end
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level then
        return false
    end
    
    if Level ~= 1 then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if not (LevelPerms and LevelPerms.Management and LevelPerms.Management.Edit) then
            TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
            return false
        end
    end
    
    if parseInt(Data.Passport) <= 0 then
        TriggerClientEvent("painel:Notify",source,"Erro","Passaporte inválido.","vermelho")
        return false
    end
    
    if Data.Mode ~= "Promote" and Data.Mode ~= "Demote" then
        TriggerClientEvent("painel:Notify",source,"Erro","Modo inválido.","vermelho")
        return false
    end
    
    local Text = Data.Mode == "Promote" and "promovido" or "rebaixado"
    local TargetIdentity = vRP.Identity(parseInt(Data.Passport))
    
    if not TargetIdentity then
        TriggerClientEvent("painel:Notify",source,"Erro","Jogador não encontrado.","vermelho")
        return false
    end
    
    vRP.SetPermission(parseInt(Data.Passport),Group,Passport,Data.Mode)
    
    local TargetSource = vRP.Source(parseInt(Data.Passport))
    if TargetSource then
        TriggerClientEvent("Notify",TargetSource,Group,"Você foi <b>" .. Text .. "</b> do seu cargo atual.","verde",5000)
    end
    
    TriggerClientEvent("painel:Notify",source,"Sucesso","Membro " .. Text .. " com sucesso.","verde")
    
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISMISS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Dismiss(Target)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Target then
        return false
    end
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level then
        return false
    end

    if Level ~= 1 then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if not (LevelPerms and LevelPerms.Management and LevelPerms.Management.Dismiss) then
            TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
            return false
        end
    end
    
    if vRP.HasGroup(Target,Group) then
        vRP.RemovePermission(Target,Group)
        return true
    end
    
    return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- ANNOUNCEMENTS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Announcements()
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return {}
    end
    
    if not vRP.HasPermission(Passport,Group) then
        return {}
    end
    
    local Result = exports.oxmysql:query_async("SELECT id AS Id, Title, Description, Timestamp AS Date, Updated, Permission FROM painel_creative_announcements WHERE LOWER(Permission) = LOWER(@Permission) ORDER BY COALESCE(Updated, Timestamp) DESC, id DESC",{ Permission = Group })
    
    return Result
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CREATEANNOUNCEMENT
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.CreateAnnouncement(Data)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Data then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end

    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if LevelPerms and LevelPerms.Announcements then
            Allowed = LevelPerms.Announcements.Create
        end
    end
    
    if not Allowed then
        TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Count = exports.oxmysql:scalar_async("SELECT COUNT(*) FROM painel_creative_announcements WHERE LOWER(Permission) = LOWER(@Permission)",{ Permission = Group }) or 0
    local Max = vRP.Permissions(Group,"Announces") or 0
    
    if Count >= Max then
        TriggerClientEvent("painel:Notify",source,"Atencao","Limite de anuncios atingido.","amarelo")
        return false
    end
    
    local Inserted = exports.oxmysql:insert_async("INSERT INTO painel_creative_announcements (Title, Description, Timestamp, Permission) VALUES (?, ?, ?, ?)",{ Data.Title, Data.Description, os.time(), Group })
    
    TriggerClientEvent("painel:Notify",source,"Sucesso","Aviso criado.","verde")
    TriggerClientEvent("painel:Close",source)
    
    return Inserted or false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATEANNOUNCEMENT
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.UpdateAnnouncement(Data)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Data or not (Data.Id or Data.id) then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if LevelPerms and LevelPerms.Announcements then
            Allowed = LevelPerms.Announcements.Edit
        end
    end
    
    if not Allowed then
        TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Id = tonumber(Data.Id or Data.id)
    if not Id then
        TriggerClientEvent("painel:Notify",source,"Erro","Identificador inválido.","vermelho")
        return false
    end
    
    local Exists = exports.oxmysql:single_async("SELECT id FROM painel_creative_announcements WHERE id = ? AND LOWER(Permission) = LOWER(?)",{ Id, Group })
    if not Exists then
        TriggerClientEvent("painel:Notify",source,"Erro","Aviso não localizado ou sem permissão.","vermelho")
        return false
    end
    
    local Affected = exports.oxmysql:update_async("UPDATE painel_creative_announcements SET Title = ?, Description = ?, Updated = ? WHERE id = ? AND LOWER(Permission) = LOWER(?)",{ Data.Title, Data.Description, os.time(), Id, Group })
    
    local Success = (Affected ~= nil and Affected ~= false)
    TriggerClientEvent("painel:Close",source)
    TriggerClientEvent("painel:Notify",source,Success and "Sucesso" or "Erro",Success and "Aviso atualizado." or "Falha ao atualizar.",Success and "verde" or "vermelho")
    
    return Success
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DESTROYANNOUNCEMENT
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.DestroyAnnouncement(Identifier)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Identifier then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if LevelPerms and LevelPerms.Announcements then
            Allowed = LevelPerms.Announcements.Delete
        end
    end
    
    if not Allowed then
        TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Id = tonumber(Identifier)
    if not Id then
        TriggerClientEvent("painel:Notify",source,"Erro","Identificador inválido.","vermelho")
        return false
    end
    
    exports.oxmysql:execute_async("DELETE FROM painel_creative_announcements WHERE id = ? AND LOWER(Permission) = LOWER(?)",{ Id, Group })
    
    TriggerClientEvent("painel:Notify",source,"Sucesso", "Aviso removido.","verde")
    TriggerClientEvent("painel:Close",source)
    
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PERKS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Perks()
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    if Level ~= 1 then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if not (LevelPerms and LevelPerms.Perks) then
            TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
            return false
        end
    end
    
    local Informations = {}
    local Default = 30
    local MembersLimit = vRP.Permissions(Group,"Members")
    local Premium = vRP.Permissions(Group,"Premium") or 0
    
    for Index,Perk in ipairs(Config.Perks) do
        local Info = {}
        for Key, Value in pairs(Perk) do
            Info[Key] = Value
        end
        
        if Perk.Type == "Members" then
            Info.Price = Perk.Price[MembersLimit] or Perk.Price[#Perk.Price]
            local GroupInfo = Groups[Group] or {}
            local MaxMembers = GroupInfo.Max or MembersLimit or Default
            Info.Active = MembersLimit >= MaxMembers or MembersLimit >= #Perk.Price
        elseif Perk.Type == "Premium" then
            Info.Price = Perk.Price
            Info.Active = Premium >= os.time()
        else
            Info.Price = Perk.Price
            Info.Active = false
        end
        
        Informations[#Informations + 1] = Info
    end
    
    return { Levels = TableLevelPainel(), List = Informations, Xp = vRP.Permissions(Group,"Experience") }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PERKSBUY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.PerksBuy(Identifier)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    if Level ~= 1 then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if not (LevelPerms and LevelPerms.Perks) then
            TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
            return false
        end
    end
    
    local Perk = Config.Perks[Identifier]
    if not Perk then
        return false
    end
    
    local Balance = vRP.Permissions(Group,"Bank")
    
    if Perk.Type == "Members" then
        local MembersAmount = vRP.Permissions(Group,"Members")
        local Cost = Perk.Price[MembersAmount] or Perk.Price[#Perk.Price]
        
        if not Cost or Balance < Cost then
            TriggerClientEvent("painel:Notify",source,"Erro","Saldo insuficiente.","vermelho")
            return false
        end
        
        vRP.PermissionsUpdate(Group,"Bank","-",Cost)
        vRP.PermissionsUpdate(Group,"Members","+",Perk.Increase)
        TriggerClientEvent("painel:Notify",source,"Sucesso","Vantagem adquirida.","verde")
        return true
    end
    
    if Perk.Level and PainelCategory(vRP.Permissions(Group,"Experience")) < Perk.Level then
        TriggerClientEvent("painel:Notify",source,"Atencao","Level <b>" .. Perk.Level .. "</b> necessario.","amarelo")
        return false
    end
    
    local Cost = type(Perk.Price) == "table" and Perk.Price[1] or Perk.Price
    if Balance < Cost then
        TriggerClientEvent("painel:Notify",source,"Erro","Saldo insuficiente.","vermelho")
        return false
    end
    
    vRP.PermissionsUpdate(Group,"Bank","-",Cost)
    
    if Perk.Type == "Premium" then
        local Current = vRP.Permissions(Group,"Premium") or 0
        local Now = os.time()
        local NewExpire = (Current > Now and Current or Now) + Perk.Increase
        exports.oxmysql:execute_async("UPDATE permissions SET Premium = ? WHERE Permission = ?",{ NewExpire, Group })
    elseif Perk.Type == "Tags" then
        exports.oxmysql:execute_async("UPDATE permissions SET Tags = Tags + ? WHERE Permission = ?",{ Perk.Increase, Group })
    elseif Perk.Type == "Announces" then
        exports.oxmysql:execute_async("UPDATE permissions SET Announces = Announces + ? WHERE Permission = ?",{ Perk.Increase, Group })
    else
        vRP.PermissionsUpdate(Group,Perk.Type,"+",Perk.Increase)
    end
    
    TriggerClientEvent("painel:Notify",source,"Sucesso","Vantagem adquirida.","verde")
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- BANK
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Bank()
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    if Level ~= 1 then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if not (LevelPerms and LevelPerms.Bank and LevelPerms.Bank.View) then
            TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
            return false
        end
    end
    
    local Consult = exports.oxmysql:query_async("SELECT * FROM painel_creative_transactions WHERE Permission = @Permission LIMIT 50",{ Permission = Group }) or {}
    local Transactions = {}
    
    for _, Row in ipairs(Consult) do
        Transactions[#Transactions + 1] = {
            Player = { Passport = Row.Passport, Name = vRP.FullName(Row.Passport) },
            To = Row.Transfer and { Passport = Row.Transfer, Name = vRP.FullName(Row.Transfer) } or false,
            Type = Row.Type,
            Value = Row.Value,
            Date = Row.Timestamp
        }
    end
    
    return { Balance = vRP.Permissions(Group, "Bank"), Historical = Transactions }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DEPOSITBANK
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.DepositBank(Value)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    Value = parseInt(Value)
    
    if not Passport or not Group or Value <= 0 then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    if Level ~= 1 then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if not (LevelPerms and LevelPerms.Bank and LevelPerms.Bank.Deposit) then
            TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
            return false
        end
    end
    
    if vRP.PaymentBank(Passport,Value) then
        exports.oxmysql:insert_async("INSERT INTO painel_creative_transactions (Type, Passport, Value, Timestamp, Transfer, Permission) VALUES (@Type, @Passport, @Value, @Timestamp, @Transfer, @Permission)",{ Type = "Deposit", Passport = Passport, Value = Value, Timestamp = os.time(), Transfer = nil, Permission = Group })
        vRP.PermissionsUpdate(Group,"Bank","+",Value)
        TriggerClientEvent("painel:Notify",source,"Sucesso","Deposito realizado.","verde")
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
    local Group = Passport and Division[Passport]
    Value = parseInt(Value)
    
    if not Passport or not Group or Value <= 0 then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    if Level ~= 1 then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if not (LevelPerms and LevelPerms.Bank and LevelPerms.Bank.Withdraw) then
            TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
            return false
        end
    end
    
    if vRP.Permissions(Group, "Bank") >= Value then
        exports.oxmysql:insert_async("INSERT INTO painel_creative_transactions (Type, Passport, Value, Timestamp, Transfer, Permission) VALUES (@Type, @Passport, @Value, @Timestamp, @Transfer, @Permission)",{ Type = "Withdraw", Passport = Passport, Value = Value, Timestamp = os.time(), Transfer = nil, Permission = Group })
        vRP.GiveBank(Passport,Value * (Config.BankTaxWithdraw or 1))
        vRP.PermissionsUpdate(Group,"Bank","-",Value)
        TriggerClientEvent("painel:Notify",source,"Sucesso","Saque realizado.","verde")
        return true
    end
    
    return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TRANSFERBANK
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.TransferBank(OtherPassport, Value)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    Value = parseInt(Value)
    OtherPassport = parseInt(OtherPassport)
    
    if not Passport or not Group or Value <= 0 or OtherPassport <= 0 then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    if Level ~= 1 then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if not (LevelPerms and LevelPerms.Bank and LevelPerms.Bank.Transfer) then
            TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
            return false
        end
    end
    
    if vRP.Permissions(Group,"Bank") >= Value then
        exports.oxmysql:insert_async("INSERT INTO painel_creative_transactions (Type, Passport, Value, Timestamp, Transfer, Permission) VALUES (@Type, @Passport, @Value, @Timestamp, @Transfer, @Permission)",{ Type = "Transfer", Passport = Passport, Value = Value, Timestamp = os.time(), Transfer = OtherPassport, Permission = Group })
        vRP.GiveBank(OtherPassport,Value * (Config.BankTaxTransfer or 1),true)
        vRP.PermissionsUpdate(Group,"Bank","-",Value)
        TriggerClientEvent("painel:Notify",source,"Sucesso","Transferencia realizada.","verde")
        return { Passport = OtherPassport, Name = vRP.FullName(OtherPassport) }
    end
    
    return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PERMISSIONS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Permissions()
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return false
    end
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level or Level ~= 1 then
        return false
    end
    
    local Hierarchy = vRP.Hierarchy(Group)
    local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
    local Response = {}
    
    for Index = 1, #Hierarchy do
        local Key = tostring(Index)
        local Owner = (Index == 1)
        local LevelPerms = Consult[Key] or {}
        
        Response[Key] = {
            Management = {
                View = LevelPerms.Management and LevelPerms.Management.View or Owner,
                Create = LevelPerms.Management and LevelPerms.Management.Create or Owner,
                Edit = LevelPerms.Management and LevelPerms.Management.Edit or Owner,
                Dismiss = LevelPerms.Management and LevelPerms.Management.Dismiss or Owner
            },
            Announcements = {
                Create = LevelPerms.Announcements and LevelPerms.Announcements.Create or Owner,
                Edit = LevelPerms.Announcements and LevelPerms.Announcements.Edit or Owner,
                Delete = LevelPerms.Announcements and LevelPerms.Announcements.Delete or Owner
            },
            Tags = {
                View = LevelPerms.Tags and LevelPerms.Tags.View or Owner,
                Create = LevelPerms.Tags and LevelPerms.Tags.Create or Owner,
                Assign = LevelPerms.Tags and LevelPerms.Tags.Assign or Owner,
                Edit = LevelPerms.Tags and LevelPerms.Tags.Edit or Owner,
                Delete = LevelPerms.Tags and LevelPerms.Tags.Delete or Owner
            },
            Bank = {
                View = LevelPerms.Bank and LevelPerms.Bank.View or Owner,
                Deposit = LevelPerms.Bank and LevelPerms.Bank.Deposit or Owner,
                Withdraw = LevelPerms.Bank and LevelPerms.Bank.Withdraw or Owner,
                Transfer = LevelPerms.Bank and LevelPerms.Bank.Transfer or Owner
            },
            Goals = {
                MyGoals = LevelPerms.Goals and LevelPerms.Goals.MyGoals or Owner,
                All = LevelPerms.Goals and LevelPerms.Goals.All or Owner,
                Edit = LevelPerms.Goals and LevelPerms.Goals.Edit or Owner
            },
            Perks = LevelPerms.Perks or Owner
        }
    end
    
    return Response
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SAVEPERMISSIONS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.SavePermissions(Permissions)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or type(Permissions) ~= "table" then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level or Level ~= 1 then
        return false
    end
    
    vRP.SetSrvData("Painel:Permissions:"..Group,Permissions,true)
    TriggerClientEvent("painel:Notify",source,"Sucesso","Permissões atualizadas.","verde")
    
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GOALS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Goals()
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return { All = {}, Goals = { Items = {}, Reward = 0 }, MyGoals = { Items = {}, Rescued = false, Week = { false, false, false, false, false, false, false } } }
    end
    
    local Goals = vRP.GetSrvData("Painel:Goals:" .. Group, true) or {}
    Goals.Items = Goals.Items or {}
    Goals.Reward = Goals.Reward or 0
    
    local MyGoals = vRP.GetSrvData("Goals:" .. Group .. ":" .. Passport, true) or {}
    MyGoals.Items = MyGoals.Items or {}
    MyGoals.Rescued = MyGoals.Rescued or false
    MyGoals.Week = MyGoals.Week or { false, false, false, false, false, false, false }
    
    local All = {}
    local Members = vRP.DataGroups(Group)
    
    for Target, _ in pairs(Members) do
        local Identity = vRP.Identity(Target)
        if Identity then
            local MemberGoals = vRP.GetSrvData("Goals:" .. Group .. ":" .. Target, true) or {}
            MemberGoals.Items = MemberGoals.Items or {}
            MemberGoals.Week = MemberGoals.Week or { false, false, false, false, false, false, false }
            
            All[#All + 1] = {
                Items = MemberGoals.Items,
                Player = { Name = vRP.FullName(Target), Passport = tostring(Target) },
                Week = MemberGoals.Week
            }
        end
    end
    
    table.sort(All, function(a, b)
        return a.Player.Name < b.Player.Name
    end)
    
    return { All = All, Goals = { Items = Goals.Items, Reward = Goals.Reward }, MyGoals = { Items = MyGoals.Items, Rescued = MyGoals.Rescued, Week = MyGoals.Week } }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATEGOALS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.UpdateGoals(Items,Reward)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if LevelPerms and LevelPerms.Goals then
            Allowed = LevelPerms.Goals.Edit
        end
    end
    
    if not Allowed then
        TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Reward = parseInt(Reward) or 0
    local Balance = vRP.Permissions(Group,"Bank") or 0
    
    if Reward > 0 and Balance < Reward then
        TriggerClientEvent("painel:Notify",source,"Erro","Saldo insuficiente no banco da organização para definir esta recompensa.","vermelho")
        return false
    end
    
    local Meta = {}
    if Items and type(Items) == "table" then
        for Item, Amount in pairs(Items) do
            if Item and type(Amount) == "number" and Amount > 0 then
                Meta[Item] = Amount
            end
        end
    end
    
    vRP.SetSrvData("Painel:Goals:"..Group,{ Items = Meta, Reward = Reward },true)
    
    local Members = vRP.DataGroups(Group)
    for Target in pairs(Members) do
        local ResetGoals = { Items = {}, Rescued = false, Week = { false, false, false, false, false, false, false } }
        vRP.SetSrvData("Goals:"..Group..":"..Target,ResetGoals,true)
    end
    
    TriggerClientEvent("painel:Notify",source,"Sucesso","Metas atualizadas com sucesso.","verde")
    TriggerClientEvent("painel:Close",source)
    
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLAIMGOALREWARD
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.ClaimGoalsReward()
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("Painel:Permissions:"..Group,true) or {}
        local LevelPerms = Consult[tostring(Level)]
        
        if LevelPerms and LevelPerms.Goals then
            Allowed = LevelPerms.Goals.MyGoals
        end
    end
    
    if not Allowed then
        TriggerClientEvent("painel:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Goals = vRP.GetSrvData("Painel:Goals:"..Group,true) or {}
    if not Goals.Items or next(Goals.Items) == nil then
        TriggerClientEvent("painel:Notify",source,"Atencao","Nenhuma meta ativa no momento.","amarelo")
        return false
    end
    
    local MyGoals = vRP.GetSrvData("Goals:"..Group..":"..Passport,true) or {}
    MyGoals.Items = MyGoals.Items or {}
    MyGoals.Rescued = MyGoals.Rescued or false
    MyGoals.Week = MyGoals.Week or { false, false, false, false, false, false, false }
    
    if MyGoals.Rescued then
        TriggerClientEvent("painel:Notify",source,"Atencao","Você já resgatou a recompensa desta meta.","amarelo")
        return false
    end
    
    local Weekday = os.date("*t")
    if not MyGoals.Week[Weekday.wday] then
        TriggerClientEvent("painel:Notify",source,"Atencao","Você ainda não completou todas as metas hoje.","amarelo")
        return false
    end
    
    local Completed = true
    for Item, Needed in pairs(Goals.Items) do
        if (MyGoals.Items[Item] or 0) < Needed then
            Completed = false
            break
        end
    end
    
    if not Completed then
        TriggerClientEvent("painel:Notify",source,"Atencao","Você ainda não completou todas as metas.","amarelo")
        return false
    end
    
    local Reward = Goals.Reward or 0
    if Reward > 0 then
        local Balance = vRP.Permissions(Group,"Bank") or 0
        if Balance < Reward then
            TriggerClientEvent("painel:Notify",source,"Erro","A organização não possui saldo suficiente para pagar a recompensa.","vermelho")
            return false
        end
        
        vRP.PermissionsUpdate(Group,"Bank","-",Reward)
        vRP.GiveBank(Passport,Reward,true)
    end
    
    MyGoals.Rescued = true
    vRP.SetSrvData("Goals:"..Group..":"..Passport,MyGoals,true)
    
    TriggerClientEvent("painel:Notify",source,"Sucesso","Recompensa resgatada com sucesso!","verde")
    TriggerClientEvent("painel:Close",source)
    
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport)
    if Passport then
        Division[Passport] = nil
    end
end)