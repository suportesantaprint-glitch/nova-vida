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
Tunnel.bindInterface("ems",Lil)
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Division = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- EMS:OPEN
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("ems:Open")
AddEventHandler("ems:Open",function(Group)
    local source = source
    local Passport = vRP.Passport(source)
    
    if Passport and vRP.HasPermission(Passport,Group) then
        Division[Passport] = Group
    else
        Division[Passport] = nil
    end
    
    TriggerClientEvent("dynamic:Close",source)
    TriggerClientEvent("ems:Opened",source)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport)
    if Passport then
        Division[Passport] = nil
    end
end)
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
    
    local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
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
        Specialties = {
            View = Permission.Specialties and Permission.Specialties.View or Owner,
            Create = Permission.Specialties and Permission.Specialties.Create or Owner,
            Assign = Permission.Specialties and Permission.Specialties.Assign or Owner,
            Edit = Permission.Specialties and Permission.Specialties.Edit or Owner,
            Delete = Permission.Specialties and Permission.Specialties.Delete or Owner
        },
        Bank = {
            View = Permission.Bank and Permission.Bank.View or Owner,
            Deposit = Permission.Bank and Permission.Bank.Deposit or Owner,
            Withdraw = Permission.Bank and Permission.Bank.Withdraw or Owner,
            Transfer = Permission.Bank and Permission.Bank.Transfer or Owner
        },
        Paramedic = {
            View = Permission.Paramedic and Permission.Paramedic.View or Owner,
            Create = Permission.Paramedic and Permission.Paramedic.Create or Owner,
            Edit = Permission.Paramedic and Permission.Paramedic.Edit or Owner,
            Delete = Permission.Paramedic and Permission.Paramedic.Delete or Owner,
            MedicPlan = (Permission.Paramedic and Permission.Paramedic.MedicPlan) or Owner,
            Avatar = (Permission.Paramedic and Permission.Paramedic.Avatar) or Owner
        },
        Consultations = {
            View = Permission.Consultations and Permission.Consultations.View or Owner,
            Create = Permission.Consultations and Permission.Consultations.Create or Owner,
            Edit = Permission.Consultations and Permission.Consultations.Edit or Owner,
            Delete = Permission.Consultations and Permission.Consultations.Delete or Owner
        },
        Exams = {
            View = Permission.Exams and Permission.Exams.View or Owner,
            Create = Permission.Exams and Permission.Exams.Create or Owner,
            Edit = Permission.Exams and Permission.Exams.Edit or Owner,
            Delete = Permission.Exams and Permission.Exams.Delete or Owner
        },
        MedicPlan = Permission.MedicPlan or Owner
    }
    
    return {
        Group = Group,
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
-- HOME
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Home()
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return {}
    end
    
    if not vRP.HasPermission(Passport,Group) then
        return {}
    end
    
    local Announcements = exports.oxmysql:query_async("SELECT id AS Id, Title, Description, Timestamp AS Date, Updated, Permission FROM painel_creative_announcements WHERE LOWER(Permission) = LOWER(?) ORDER BY COALESCE(Updated, Timestamp) DESC, id DESC LIMIT 5",{ Group }) or {}
    
    local DoctorsInService = {}
    local Groups = vRP.DataGroups(Group) or {}
    local Service = vRP.NumPermission(Group) or {}
    
    for Target in pairs(Groups) do
        if Service[Target] and vRP.Source(Target) then
            local Identity = vRP.Identity(Target)
            local Hierarchy = vRP.HasPermission(Target, Group)
            if Identity and Hierarchy then
                DoctorsInService[#DoctorsInService + 1] = {
                    Passport = Target,
                    Name = vRP.FullName(Target),
                    Hierarchy = Hierarchy
                }
            end
        end
    end
    
    local Consultations = exports.oxmysql:query_async("SELECT id, Passport, Doctor, Timestamp, Reason, Status, Description FROM ems_creative_consultations WHERE LOWER(Permission) = LOWER(?) AND Status = 'appointment' ORDER BY Timestamp ASC LIMIT 10",{ Group }) or {}
    
    local ScheduledConsultations = {}
    for _, Consult in ipairs(Consultations) do
        ScheduledConsultations[#ScheduledConsultations + 1] = {
            Id = Consult.id,
            Patient = {
                Passport = Consult.Passport,
                Name = vRP.FullName(Consult.Passport) or ""
            },
            Doctor = Consult.Doctor and {
                Passport = Consult.Doctor,
                Name = vRP.FullName(Consult.Doctor) or ""
            } or nil,
            Date = Consult.Timestamp,
            Reason = Consult.Reason or "",
            Description = Consult.Description
        }
    end
    
    local Exams = exports.oxmysql:query_async("SELECT id, Passport, Doctor, Timestamp, Name, Status, Description FROM ems_creative_exams WHERE LOWER(Permission) = LOWER(?) AND Status = 'appointment' ORDER BY Timestamp ASC LIMIT 10",{ Group }) or {}
    
    local ScheduledExams = {}
    for _, Exam in ipairs(Exams) do
        ScheduledExams[#ScheduledExams + 1] = {
            Id = Exam.id,
            Patient = {
                Passport = Exam.Passport,
                Name = vRP.FullName(Exam.Passport) or ""
            },
            Doctor = Exam.Doctor and {
                Passport = Exam.Doctor,
                Name = vRP.FullName(Exam.Doctor) or ""
            } or nil,
            Date = Exam.Timestamp,
            Name = Exam.Name or "",
            Description = Exam.Description
        }
    end
    
    return {
        Announcements = Announcements,
        Users = DoctorsInService,
        Consultations = ScheduledConsultations,
        Exams = ScheduledExams
    }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- USER
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.User(TargetPassport)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return nil
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return nil
    end
    
    local Allowed = (Level == 1 or Group == "Admin")
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Paramedic then
            Allowed = Permission.Paramedic.View
        else
            Allowed = false
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return nil
    end
    
    local SelectedPassport = parseInt(TargetPassport)
    if SelectedPassport <= 0 then
        return nil
    end
    
    local Identity = vRP.Identity(SelectedPassport)
    if not Identity then
        return nil
    end
    
    local Avatar = exports.oxmysql:single_async("SELECT Image FROM avatars WHERE Passport = ?", { SelectedPassport })
    local Records = exports.oxmysql:query_async("SELECT id, Doctor, Timestamp, Reason, Status, Description FROM ems_creative_consultations WHERE Passport = ? AND Permission = ? ORDER BY Timestamp DESC",{ SelectedPassport, Group }) or {}
    
    local Historical = {}
    for _, Record in ipairs(Records) do
        local DoctorPassport = tonumber(Record.Doctor) or 0
        local DoctorName = DoctorPassport > 0 and (vRP.FullName(DoctorPassport) or "") or ""
        
        Historical[#Historical + 1] = {
            Id = tonumber(Record.id) or 0,
            Doctor = {
                Passport = DoctorPassport,
                Name = tostring(DoctorName)
            },
            Date = tonumber(Record.Timestamp) or 0,
            Reason = tostring(Record.Reason) or "",
            Status = tostring(Record.Status) or "appointment",
            Description = tostring(Record.Description) or ""
        }
    end
    
    return {
        Passport = SelectedPassport,
        Name = vRP.FullName(SelectedPassport),
        Phone = vRP.Phone(SelectedPassport),
        Blood = Sanguine(Identity.Blood),
        Avatar = Avatar and Avatar.Image or "",
        MedicPlan = vRP.DatatableInformation(SelectedPassport, "MedicPlan") or false,
        Historical = Historical
    }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- AVATAR
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Avatar(TargetPassport,Image)
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
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Paramedic then
            Allowed = Permission.Paramedic.Avatar
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Target = parseInt(TargetPassport)
    if Target <= 0 or not Image or Image == "" then
        return false
    end
    
    local Avatar = exports.oxmysql:single_async("SELECT id FROM avatars WHERE Passport = ?", { Target })
    if Avatar then
        exports.oxmysql:execute_async("UPDATE avatars SET Image = ?, Permission = ? WHERE Passport = ?", { Image, Group, Target })
    else
        exports.oxmysql:insert_async("INSERT INTO avatars (Passport, Image, Permission) VALUES (?, ?, ?)", { Target, Image, Group })
    end
    
    TriggerClientEvent("ems:Notify",source,"Sucesso","Avatar atualizado.","verde")
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SEARCHUSER
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.SearchUser(Search)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return {}
    end
    
    if not vRP.HasPermission(Passport, Group) then
        return {}
    end
    
    local Results = {}
    local SearchStr = tostring(Search or "")
    local Lookup = "%" .. SearchStr:lower() .. "%"
    
    local Users = exports.oxmysql:query_async("SELECT id AS Passport, Name, Lastname FROM characters WHERE Deleted = 0 AND (LOWER(Name) LIKE ? OR LOWER(Lastname) LIKE ? OR CAST(id AS CHAR) = ?) LIMIT 50",{ Lookup, Lookup, SearchStr }) or {}
    
    for _, User in ipairs(Users) do
        Results[#Results + 1] = {
            Passport = User.Passport,
            Name = User.Name .. " " .. User.Lastname,
            MedicPlan = vRP.DatatableInformation(User.Passport,"MedicPlan") or false
        }
    end
    
    return Results
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MEDICPLAN
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.MedicPlan(TargetPassport)
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
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Paramedic then
            Allowed = Permission.Paramedic.MedicPlan
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Target = parseInt(TargetPassport)
    if Target <= 0 then
        return false
    end
    
    local Identity = vRP.Identity(Target)
    if not Identity then
        return false
    end
    
    local Duration = Config.MedicPlanDuration or 0
    local Current = vRP.DatatableInformation(Target,"MedicPlan") or 0
    local Now = os.time()
    local Expire = (Current > Now and Current or Now) + Duration
    
    vRP.UpdateDatatable(Target,"MedicPlan",Expire)
    TriggerClientEvent("ems:Notify",source,"Sucesso","Plano medico atualizado.","verde")
    
    return Expire
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- USERCONSULTATIONS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.UserConsultations(TargetPassport)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return {}
    end
    
    local Target = parseInt(TargetPassport)
    if Target <= 0 then
        return {}
    end
    
    local Consult = exports.oxmysql:query_async("SELECT id, Doctor, Timestamp, Reason, Status, Description FROM ems_creative_consultations WHERE Passport = ? AND Permission = ? ORDER BY Timestamp DESC",{ Target, Group }) or {}
    
    local Results = {}
    for _, Record in ipairs(Consult) do
        local DoctorPassport = tonumber(Record.Doctor) or 0
        local DoctorName = DoctorPassport > 0 and (vRP.FullName(DoctorPassport) or "") or ""
        
        Results[#Results + 1] = {
            Id = tonumber(Record.id) or 0,
            Doctor = { Passport = DoctorPassport, Name = DoctorName },
            Date = tonumber(Record.Timestamp) or 0,
            Reason = tostring(Record.Reason) or "",
            Status = tostring(Record.Status) or "appointment",
            Description = tostring(Record.Description) or ""
        }
    end
    
    return Results
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- USEREXAMS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.UserExams(TargetPassport)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return {}
    end
    
    local Target = parseInt(TargetPassport)
    if Target <= 0 then
        return {}
    end
    
    local Consult = exports.oxmysql:query_async("SELECT id, Doctor, Timestamp, Name, Status, Description FROM ems_creative_exams WHERE Passport = ? AND Permission = ? ORDER BY Timestamp DESC",{ Target, Group }) or {}
    
    local Results = {}
    for _, Record in ipairs(Consult) do
        local DoctorPassport = tonumber(Record.Doctor) or 0
        local DoctorName = DoctorPassport > 0 and (vRP.FullName(DoctorPassport) or "") or ""
        
        Results[#Results + 1] = {
            Id = tonumber(Record.id) or 0,
            Doctor = { Passport = DoctorPassport, Name = DoctorName },
            Date = tonumber(Record.Timestamp) or 0,
            Name = tostring(Record.Name) or "",
            Status = tostring(Record.Status) or "appointment",
            Description = tostring(Record.Description) or ""
        }
    end
    
    return Results
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MEMBERS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Members(Ranking)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return { Members = {}, Max = 0 }
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return { Members = {}, Max = 0 }
    end
    
    local Allowed = (Level == 1 or Group == "Admin")
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Management then
            Allowed = Permission.Management.View
        else
            Allowed = false
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return { Members = {}, Max = 0 }
    end
    
    local Members = {}
    local Groups = vRP.DataGroups(Group) or {}
    local Service = vRP.NumPermission(Group) or {}
    
    local Specialties = exports.oxmysql:query_async("SELECT Name, Members FROM ems_creative_specialties WHERE LOWER(Permission) = LOWER(?)",{ Group }) or {}
    for _, Specialty in ipairs(Specialties) do
        Specialty.Decoded = Specialty.Members and json.decode(Specialty.Members) or {}
    end
    
    for Target in pairs(Groups) do
        local Identity = vRP.Identity(Target)
        local Hierarchy = vRP.HasPermission(Target, Group)
        
        if Identity and Hierarchy then
            local Assigned = {}
            for _, Specialty in ipairs(Specialties) do
                for _, Number in ipairs(Specialty.Decoded) do
                    if tonumber(Number) == tonumber(Target) then
                        table.insert(Assigned, Specialty.Name)
                        break
                    end
                end
            end
            
            local Played = vRP.Playing(Target, Group) or 0
            local Hours = math.floor(Played / 3600)
            local Minutes = math.floor((Played % 3600) / 60)
            local TimerLabel = Hours > 0 and string.format("%dh %dmin", Hours, Minutes) or string.format("%dmin", Minutes)
            local Status = vRP.Source(Target) and ("Ativo a " .. TimerLabel) or ("Inativo a " .. TimerLabel)
            
            Members[#Members + 1] = {
                Passport = Target,
                Name = vRP.FullName(Target),
                Hierarchy = Hierarchy,
                Service = Service[Target] and 1 or 0,
                Hours = Played,
                Status = Status,
                Specialties = Assigned
            }
        end
    end
    
    if Ranking then
        table.sort(Members, function(a, b)
            return a.Hours > b.Hours
        end)
    end
    
    return { Members = Members, Max = vRP.Permissions(Group,"Members") or 0 }
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
    
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Management then
            Allowed = Permission.Management.Create
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    Target = parseInt(Target)
    if Target <= 0 or Target == Passport then
        return true
    end
    
    if not vRP.GetUserType(Target,"Work") then
        local TargetSource = vRP.Source(Target)
        if TargetSource and vRP.Request(TargetSource,"Grupos","Você foi convidado(a) para participar do grupo <b>" .. Group .. "</b>, deseja entrar?") then
            vRP.SetPermission(Target,Group)
            TriggerClientEvent("ems:Notify",source,"Sucesso","Passaporte adicionado.","verde")
        end
    end
    
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
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Management then
            Allowed = Permission.Management.Dismiss
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    if vRP.HasGroup(Target,Group) then
        vRP.RemovePermission(Target,Group)
        return true
    end
    
    return false
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
    
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Management then
            Allowed = Permission.Management.Edit
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Text = Data.Mode == "Promote" and "promovido" or "rebaixado"
    vRP.SetPermission(Data.Passport,Group,Passport,Data.Mode)
    
    local TargetSource = vRP.Source(Data.Passport)
    if TargetSource then
        TriggerClientEvent("Notify",TargetSource,Group,"Você foi <b>" .. Text .. "</b> do seu cargo atual.","verde",5000)
    end
    
    TriggerClientEvent("ems:Notify",source,"Sucesso","Membro " .. Text .. " com sucesso.","verde")
    
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SPECIALTIES
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Specialties()
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return {}
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return {}
    end
    
    local Allowed = (Level == 1 or Group == "Admin")
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Specialties then
            Allowed = Permission.Specialties.View
        else
            Allowed = false
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return {}
    end
    
    local Consult = exports.oxmysql:query_async("SELECT * FROM ems_creative_specialties WHERE LOWER(Permission) = LOWER(?)",{ Group }) or {}
    local Specialties = {}
    
    for _, Row in ipairs(Consult) do
        Specialties[#Specialties + 1] = {
            Id = Row.id,
            Name = Row.Name,
            Members = json.decode(Row.Members) or {}
        }
    end
    
    return Specialties
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CREATESPECIALTY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.CreateSpecialty(Data)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Data or not Data.Name then
        return false
    end
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1 or Group == "Admin")
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Specialties then
            Allowed = Permission.Specialties.Create
        else
            Allowed = false
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local InsertId = exports.oxmysql:insert_async("INSERT INTO ems_creative_specialties (Name, Members, Permission) VALUES (?, ?, ?)",{ Data.Name, "[]", Group })
    if InsertId then
        TriggerClientEvent("ems:Notify",source,"Sucesso","Especialidade criada.","verde")
        return InsertId
    end
    
    return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATESPECIALTY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.UpdateSpecialty(Data)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Data or not Data.Id or not Data.Name then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    -- Verificar permissão
    local Allowed = (Level == 1 or Group == "Admin")
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Specialties then
            Allowed = Permission.Specialties.Edit
        else
            Allowed = false
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    exports.oxmysql:execute_async("UPDATE ems_creative_specialties SET Name = ? WHERE id = ? AND Permission = ?",{ Data.Name, Data.Id, Group })
    TriggerClientEvent("ems:Notify",source,"Sucesso","Especialidade atualizada.","verde")
    
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GETSPECIALTY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.GetSpecialty(Identifier)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Identifier then
        return nil
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return nil
    end
    
    local Allowed = (Level == 1 or Group == "Admin")
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Specialties then
            Allowed = Permission.Specialties.Assign
        else
            Allowed = false
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return nil
    end
    
    local Consult = exports.oxmysql:single_async("SELECT id, Name, Members FROM ems_creative_specialties WHERE Id = ? AND LOWER(Permission) = LOWER(?)", { Identifier, Group })
    if not Consult then
        return nil
    end
    
    local MembersList = json.decode(Consult.Members) or {}
    local FormattedMembers = {}
    for _, MemberPassport in ipairs(MembersList) do
        FormattedMembers[#FormattedMembers + 1] = {
            Passport = MemberPassport,
            Name = vRP.FullName(MemberPassport) or ""
        }
    end
    
    return { Id = Consult.id, Name = Consult.Name, Members = FormattedMembers }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- ASSIGNSPECIALTY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.AssignSpecialty(Data)
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
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Specialties then
            Allowed = Permission.Specialties.Assign
        else
            Allowed = false
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Consult = exports.oxmysql:single_async("SELECT id, Name, Members FROM ems_creative_specialties WHERE Id = ? AND LOWER(Permission) = LOWER(?)", { Data.Id, Group })
    if not Consult then
        return false
    end
    
    local Members = json.decode(Consult.Members) or {}
    local TargetPassport = tonumber(Data.Passport) or Data.Passport
    local Found = false
    
    for _, Member in ipairs(Members) do
        if tonumber(Member) == tonumber(TargetPassport) then
            Found = true
            break
        end
    end
    
    if not Found then
        Members[#Members + 1] = TargetPassport
        exports.oxmysql:execute_async("UPDATE ems_creative_specialties SET Members = ? WHERE Id = ?", { json.encode(Members), Data.Id })
        TriggerClientEvent("ems:Notify",source,"Sucesso","Especialidade atribuída.","verde")
        return { Passport = TargetPassport, Name = vRP.FullName(TargetPassport) or "" }
    end
    
    return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- REMOVESPECIALTY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.RemoveSpecialty(Data)
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
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Specialties then
            Allowed = Permission.Specialties.Assign
        else
            Allowed = false
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Consult = exports.oxmysql:single_async("SELECT id, Name, Members FROM ems_creative_specialties WHERE Id = ? AND LOWER(Permission) = LOWER(?)",{ Data.Id, Group })
    if not Consult then
        return false
    end
    
    local Members = json.decode(Consult.Members) or {}
    local TargetPassport = tonumber(Data.Passport) or Data.Passport
    
    for Index, Member in ipairs(Members) do
        if tonumber(Member) == tonumber(TargetPassport) then
            table.remove(Members, Index)
            break
        end
    end
    
    exports.oxmysql:execute_async("UPDATE ems_creative_specialties SET Members = ? WHERE Id = ?",{ json.encode(Members), Data.Id })
    TriggerClientEvent("ems:Notify",source,"Sucesso","Especialidade removida.","verde")
    
    return { Passport = Data.Passport }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DESTROYSPECIALTY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.DestroySpecialty(Identifier)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Identifier then
        return false
    end
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1 or Group == "Admin")
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Specialties then
            Allowed = Permission.Specialties.Delete
        else
            Allowed = false
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    exports.oxmysql:execute_async("DELETE FROM ems_creative_specialties WHERE id = ? AND Permission = ?",{ Identifier, Group })
    TriggerClientEvent("ems:Notify",source,"Sucesso","Especialidade removida.","verde")
    
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONSULTATIONS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Consultations()
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return {}
    end
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level then
        return {}
    end
    
    local Allowed = true
    if Level ~= 1 then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Consultations then
            Allowed = Permission.Consultations.View
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return {}
    end
    
    local Consult = exports.oxmysql:query_async("SELECT id, Passport, Doctor, Timestamp, Reason, Status, Description, Permission FROM ems_creative_consultations WHERE LOWER(Permission) = LOWER(?) ORDER BY Timestamp DESC, id DESC",{ Group }) or {}
    
    local Results = {}
    for _, Record in ipairs(Consult) do
        Results[#Results + 1] = {
            Id = Record.id,
            Patient = { Passport = Record.Passport, Name = vRP.FullName(Record.Passport) or "" },
            Doctor = { Passport = Record.Doctor, Name = vRP.FullName(Record.Doctor) or "" },
            Date = Record.Timestamp,
            Reason = Record.Reason or "",
            Status = Record.Status or "appointment",
            Description = Record.Description,
            Permission = Record.Permission
        }
    end
    
    return Results
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GETCONSULTATION
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.GetConsultation(Identifier)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Identifier then
        return nil
    end
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level then
        return nil
    end
    
    local Consult = exports.oxmysql:single_async("SELECT id, Passport, Doctor, Timestamp, Reason, Status, Description FROM ems_creative_consultations WHERE id = ? AND Permission = ?",{ Identifier, Group })
    
    if not Consult then
        return nil
    end
    
    return {
        Id = Consult.id,
        Patient = { Passport = Consult.Passport, Name = vRP.FullName(Consult.Passport) or "" },
        Doctor = { Passport = Consult.Doctor, Name = vRP.FullName(Consult.Doctor) or "" },
        Date = Consult.Timestamp,
        Reason = Consult.Reason or "",
        Status = Consult.Status or "appointment",
        Description = Consult.Description
    }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CREATECONSULTATION
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.CreateConsultation(Data)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Data or not Data.Passport or not Data.Description then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Consultations then
            Allowed = Permission.Consultations.Create
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Target = parseInt(Data.Passport)
    if Target <= 0 or not vRP.Identity(Target) then
        return false
    end
    
    local Timestamp = os.time()
    local TimestampField = Data.Timestamp or Data.Date
    if TimestampField then
        local TimestampValue = tonumber(TimestampField)
        if TimestampValue and TimestampValue > 0 then
            if TimestampValue > 10000000000 then
                TimestampValue = math.floor(TimestampValue / 1000)
            end
            Timestamp = TimestampValue
        end
    end
    
    exports.oxmysql:insert_async("INSERT INTO ems_creative_consultations (Passport, Doctor, Timestamp, Reason, Status, Description, Permission) VALUES (?, ?, ?, ?, ?, ?, ?)",{ Target, Passport, Timestamp, Data.Reason or "", Data.Status or "appointment", Data.Description, Group })
    
    TriggerClientEvent("ems:Notify",source,"Sucesso","Consulta criada.","verde")
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATECONSULTATION
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.UpdateConsultation(Data)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Data or not Data.Id or not Data.Description then
        return false
    end
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Consultations then
            Allowed = Permission.Consultations.Edit
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local UpdateFields = { Data.Reason or "", Data.Status or "appointment", Data.Description }
    local UpdateQuery = "UPDATE ems_creative_consultations SET Reason = ?, Status = ?, Description = ?"
    
    local TimestampField = Data.Timestamp or Data.Date
    if TimestampField then
        local TimestampValue = tonumber(TimestampField)
        if TimestampValue and TimestampValue > 0 then
            if TimestampValue > 10000000000 then
                TimestampValue = math.floor(TimestampValue / 1000)
            end
            UpdateQuery = "UPDATE ems_creative_consultations SET Reason = ?, Status = ?, Description = ?, Timestamp = ?"
            table.insert(UpdateFields,TimestampValue)
        end
    end
    
    table.insert(UpdateFields,Data.Id)
    table.insert(UpdateFields,Group)
    
    exports.oxmysql:execute_async(UpdateQuery .. " WHERE id = ? AND Permission = ?",UpdateFields)
    TriggerClientEvent("ems:Notify",source,"Sucesso","Consulta atualizada.","verde")
    
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DESTROYCONSULTATION
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.DestroyConsultation(Identifier)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Identifier then
        return false
    end
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Consultations then
            Allowed = Permission.Consultations.Delete
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    exports.oxmysql:execute_async("DELETE FROM ems_creative_consultations WHERE id = ? AND Permission = ?",{ Identifier, Group })
    TriggerClientEvent("ems:Notify",source,"Sucesso","Consulta removida.","verde")
    
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- EXAMS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Exams()
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group then
        return {}
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return {}
    end
    
    -- Verificar permissão
    local Allowed = true
    if Level ~= 1 then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Exams then
            Allowed = Permission.Exams.View
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return {}
    end
    
    local Consult = exports.oxmysql:query_async("SELECT id, Passport, Doctor, Timestamp, Name, Status, Description, Permission FROM ems_creative_exams WHERE LOWER(Permission) = LOWER(?) ORDER BY Timestamp DESC, id DESC",{ Group }) or {}
    
    local Results = {}
    for _, Record in ipairs(Consult) do
        Results[#Results + 1] = {
            Id = Record.id,
            Patient = { Passport = Record.Passport, Name = vRP.FullName(Record.Passport) or "" },
            Doctor = { Passport = Record.Doctor, Name = vRP.FullName(Record.Doctor) or "" },
            Date = Record.Timestamp,
            Name = Record.Name or "",
            Status = Record.Status or "appointment",
            Description = Record.Description,
            Permission = Record.Permission
        }
    end
    
    return Results
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GETEXAM
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.GetExam(Identifier)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Identifier then
        return nil
    end
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level then
        return nil
    end
    
    local Consult = exports.oxmysql:single_async("SELECT id, Passport, Doctor, Timestamp, Name, Status, Description FROM ems_creative_exams WHERE id = ? AND Permission = ?",{ Identifier, Group })
    
    if not Consult then
        return nil
    end
    
    return {
        Id = Consult.id,
        Patient = { Passport = Consult.Passport, Name = vRP.FullName(Consult.Passport) or "" },
        Doctor = { Passport = Consult.Doctor, Name = vRP.FullName(Consult.Doctor) or "" },
        Date = Consult.Timestamp,
        Name = Consult.Name or "",
        Status = Consult.Status or "appointment",
        Description = Consult.Description
    }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CREATEEXAM
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.CreateExam(Data)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Data or not Data.Passport or not Data.Description then
        return false
    end
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Exams then
            Allowed = Permission.Exams.Create
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Target = parseInt(Data.Passport)
    if Target <= 0 or not vRP.Identity(Target) then
        return false
    end
    
    local Timestamp = os.time()
    local TimestampField = Data.Timestamp or Data.Date
    if TimestampField then
        local TimestampValue = tonumber(TimestampField)
        if TimestampValue and TimestampValue > 0 then
            if TimestampValue > 10000000000 then
                TimestampValue = math.floor(TimestampValue / 1000)
            end
            Timestamp = TimestampValue
        end
    end
    
    exports.oxmysql:insert_async("INSERT INTO ems_creative_exams (Passport, Doctor, Timestamp, Name, Status, Description, Permission) VALUES (?, ?, ?, ?, ?, ?, ?)",{ Target, Passport, Timestamp, Data.Name or "", Data.Status or "appointment", Data.Description, Group })
    
    TriggerClientEvent("ems:Notify", source, "Sucesso", "Exame criado.", "verde")
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATEEXAM
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.UpdateExam(Data)
    local source = source
    local Passport = vRP.Passport(source)
    local Group = Passport and Division[Passport]
    
    if not Passport or not Group or not Data or not Data.Id or not Data.Description then
        return false
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Exams then
            Allowed = Permission.Exams.Edit
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local UpdateFields = { Data.Name or "", Data.Status or "appointment", Data.Description }
    local UpdateQuery = "UPDATE ems_creative_exams SET Name = ?, Status = ?, Description = ?"
    
    local TimestampField = Data.Timestamp or Data.Date
    if TimestampField then
        local TimestampValue = tonumber(TimestampField)
        if TimestampValue and TimestampValue > 0 then
            if TimestampValue > 10000000000 then
                TimestampValue = math.floor(TimestampValue / 1000)
            end
            UpdateQuery = "UPDATE ems_creative_exams SET Name = ?, Status = ?, Description = ?, Timestamp = ?"
            table.insert(UpdateFields,TimestampValue)
        end
    end
    
    table.insert(UpdateFields,Data.Id)
    table.insert(UpdateFields,Group)
    
    exports.oxmysql:execute_async(UpdateQuery .. " WHERE id = ? AND Permission = ?",UpdateFields)
    TriggerClientEvent("ems:Notify",source,"Sucesso","Exame atualizado.","verde")
    
    return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DESTROYEXAM
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.DestroyExam(Identifier)
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
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Exams then
            Allowed = Permission.Exams.Delete
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    exports.oxmysql:execute_async("DELETE FROM ems_creative_exams WHERE id = ? AND Permission = ?",{ Identifier, Group })
    TriggerClientEvent("ems:Notify",source,"Sucesso","Exame removido.","verde")
    
    return true
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
    
    if not vRP.HasPermission(Passport, Group) then
        return {}
    end
    
    local Result = exports.oxmysql:query_async("SELECT id AS Id, Title, Description, Timestamp AS Date, Updated, Permission FROM painel_creative_announcements WHERE LOWER(Permission) = LOWER(?) ORDER BY COALESCE(Updated, Timestamp) DESC, id DESC",{ Group })
    
    return Result or {}
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
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Announcements then
            Allowed = Permission.Announcements.Create
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Inserted = exports.oxmysql:insert_async("INSERT INTO painel_creative_announcements (Title, Description, Timestamp, Permission) VALUES (?, ?, ?, ?)",{ Data.Title, Data.Description, os.time(), Group })
    
    TriggerClientEvent("ems:Notify",source,"Sucesso","Aviso criado.","verde")
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
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Announcements then
            Allowed = Permission.Announcements.Edit
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Id = tonumber(Data.Id or Data.id)
    if not Id then
        TriggerClientEvent("ems:Notify",source,"Erro","Identificador inválido.","vermelho")
        return false
    end
    
    local Exists = exports.oxmysql:single_async("SELECT id FROM painel_creative_announcements WHERE id = ? AND LOWER(Permission) = LOWER(?)",{ Id, Group })
    if not Exists then
        TriggerClientEvent("ems:Notify", source, "Erro", "Aviso não localizado ou sem permissão.", "vermelho")
        return false
    end
    
    local Affected = exports.oxmysql:update_async("UPDATE painel_creative_announcements SET Title = ?, Description = ?, Updated = ? WHERE id = ? AND LOWER(Permission) = LOWER(?)",{ Data.Title, Data.Description, os.time(), Id, Group })
    
    local Success = (Affected ~= nil and Affected ~= false)
    TriggerClientEvent("ems:Notify", source, Success and "Sucesso" or "Erro", Success and "Aviso atualizado." or "Falha ao atualizar.", Success and "verde" or "vermelho")
    
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
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level then
        return false
    end
    
    local Allowed = (Level == 1)
    if not Allowed then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if Permission and Permission.Announcements then
            Allowed = Permission.Announcements.Delete
        end
    end
    
    if not Allowed then
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
        return false
    end
    
    local Id = tonumber(Identifier)
    if not Id then
        TriggerClientEvent("ems:Notify",source,"Erro","Identificador inválido.","vermelho")
        return false
    end
    
    exports.oxmysql:execute_async("DELETE FROM painel_creative_announcements WHERE id = ? AND LOWER(Permission) = LOWER(?)",{ Id, Group })
    
    TriggerClientEvent("ems:Notify",source,"Sucesso","Aviso removido.","verde")
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
        return { Balance = 0, Historical = {} }
    end
    
    local Level = vRP.HasPermission(Passport, Group)
    if not Level then
        return { Balance = 0, Historical = {} }
    end
    
    if Level ~= 1 then
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if not (Permission and Permission.Bank and Permission.Bank.View) then
            TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
            return { Balance = 0, Historical = {} }
        end
    end
    
    local Consult = exports.oxmysql:query_async("SELECT * FROM painel_creative_transactions WHERE Permission = ? ORDER BY Timestamp DESC LIMIT 50",{ Group }) or {}
    local Historical = {}
    
    for _, Data in ipairs(Consult) do
        table.insert(Historical, {
            Player = { Passport = Data.Passport, Name = vRP.FullName(Data.Passport) },
            To = Data.Transfer and { Passport = Data.Transfer, Name = vRP.FullName(Data.Transfer) } or nil,
            Type = Data.Type,
            Value = Data.Value,
            Date = Data.Timestamp
        })
    end
    
    return { Balance = vRP.Permissions(Group,"Bank") or 0, Historical = Historical }
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
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if not (Permission and Permission.Bank and Permission.Bank.Deposit) then
            TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
            return false
        end
    end
    
    if vRP.PaymentBank(Passport,Value) then
        exports.oxmysql:insert_async("INSERT INTO painel_creative_transactions (Type, Passport, Value, Timestamp, Transfer, Permission) VALUES (?, ?, ?, ?, ?, ?)",{ "Deposit", Passport, Value, os.time(), nil, Group })
        vRP.PermissionsUpdate(Group,"Bank","+",Value)
        TriggerClientEvent("ems:Notify",source,"Sucesso","Deposito realizado.","verde")
        return true
    else
        TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui dinheiro suficiente.","amarelo")
        return false
    end
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
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if not (Permission and Permission.Bank and Permission.Bank.Withdraw) then
            TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
            return false
        end
    end
    
    local BankBalance = vRP.Permissions(Group,"Bank") or 0
    if BankBalance >= Value then
        exports.oxmysql:insert_async("INSERT INTO painel_creative_transactions (Type, Passport, Value, Timestamp, Transfer, Permission) VALUES (?, ?, ?, ?, ?, ?)",{ "Withdraw", Passport, Value, os.time(), nil, Group })
        vRP.GiveBank(Passport,Value * (Config.BankTaxWithdraw or 1))
        vRP.PermissionsUpdate(Group,"Bank","-",Value)
        TriggerClientEvent("ems:Notify",source,"Sucesso","Saque realizado.","verde")
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
        local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
        local Permission = Consult[tostring(Level)]
        
        if not (Permission and Permission.Bank and Permission.Bank.Transfer) then
            TriggerClientEvent("ems:Notify",source,"Atencao","Você não possui permissão.","amarelo")
            return false
        end
    end
    
    local BankBalance = vRP.Permissions(Group,"Bank") or 0
    
    if BankBalance >= Value then
        exports.oxmysql:insert_async("INSERT INTO painel_creative_transactions (Type, Passport, Value, Timestamp, Transfer, Permission) VALUES (?, ?, ?, ?, ?, ?)",{ "Transfer", Passport, Value, os.time(), OtherPassport, Group })
        vRP.GiveBank(OtherPassport,Value * (Config.BankTaxTransfer or 1),true)
        vRP.PermissionsUpdate(Group,"Bank","-",Value)
        TriggerClientEvent("ems:Notify",source,"Sucesso","Transferencia realizada.","verde")
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
        return {}
    end
    
    local Level = vRP.HasPermission(Passport,Group)
    if not Level or Level ~= 1 then
        return {}
    end
    
    local Hierarchy = vRP.Hierarchy(Group)
    local Consult = vRP.GetSrvData("EMS:Permissions:"..Group,true) or {}
    local Response = {}
    
    for Index = 1, #Hierarchy do
        local Key = tostring(Index)
        local Owner = (Index == 1)
        local Permission = Consult[Key] or {}
        
        Response[Key] = {
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
            Specialties = {
                View = Permission.Specialties and Permission.Specialties.View or Owner,
                Create = Permission.Specialties and Permission.Specialties.Create or Owner,
                Assign = Permission.Specialties and Permission.Specialties.Assign or Owner,
                Edit = Permission.Specialties and Permission.Specialties.Edit or Owner,
                Delete = Permission.Specialties and Permission.Specialties.Delete or Owner
            },
            Bank = {
                View = Permission.Bank and Permission.Bank.View or Owner,
                Deposit = Permission.Bank and Permission.Bank.Deposit or Owner,
                Withdraw = Permission.Bank and Permission.Bank.Withdraw or Owner,
                Transfer = Permission.Bank and Permission.Bank.Transfer or Owner
            },
            Paramedic = {
                View = Permission.Paramedic and Permission.Paramedic.View or Owner,
                Create = Permission.Paramedic and Permission.Paramedic.Create or Owner,
                Edit = Permission.Paramedic and Permission.Paramedic.Edit or Owner,
                Delete = Permission.Paramedic and Permission.Paramedic.Delete or Owner,
                MedicPlan = (Permission.Paramedic and Permission.Paramedic.MedicPlan) or Owner,
                Avatar = (Permission.Paramedic and Permission.Paramedic.Avatar) or Owner
            },
            Consultations = {
                View = Permission.Consultations and Permission.Consultations.View or Owner,
                Create = Permission.Consultations and Permission.Consultations.Create or Owner,
                Edit = Permission.Consultations and Permission.Consultations.Edit or Owner,
                Delete = Permission.Consultations and Permission.Consultations.Delete or Owner
            },
            Exams = {
                View = Permission.Exams and Permission.Exams.View or Owner,
                Create = Permission.Exams and Permission.Exams.Create or Owner,
                Edit = Permission.Exams and Permission.Exams.Edit or Owner,
                Delete = Permission.Exams and Permission.Exams.Delete or Owner
            }
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
    
    if not Passport or not Group or not Permissions or type(Permissions) ~= "table" then
        return false
    end
    
    vRP.SetSrvData("EMS:Permissions:"..Group,Permissions,true)
    TriggerClientEvent("ems:Notify",source,"Sucesso","Permissões atualizadas.","verde")
    
    return true
end