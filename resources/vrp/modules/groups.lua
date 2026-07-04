-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Service = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- FORSERVICE
-----------------------------------------------------------------------------------------------------------------------------------------
for Permission in pairs(Groups) do
	Service[Permission] = {}
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GROUPS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.Groups()
	return Groups
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- USERDOMINATION
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.UserDomination(Passport)
	local Group = false

	for Index,v in pairs(Groups) do
		if v.Domination then
			if vRP.HasPermission(Passport,Index) then
				Group = Index
				break
			end
		end
	end

	return Group
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- USERSALARYS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.UserSalarys(Passport)
	local Valuation = 0

	for Permission,v in pairs(Groups) do
		local SalaryLevels = v.Salary
		if SalaryLevels then
			local Level = vRP.HasService(Passport,Permission)
			if Level and SalaryLevels[Level] then
				Valuation = Valuation + SalaryLevels[Level]
			end
		end
	end

	return Valuation
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- USERGROUPS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.UserGroups(Passport)
	local Table = {}
	for Permission in pairs(Groups) do
		local CheckPermission = vRP.HasPermission(Passport,Permission)
		if CheckPermission then
			Table[Permission] = CheckPermission
		end
	end

	return Table
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DATAGROUPS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.DataGroups(Permission)
	local Table = vRP.GetSrvData("Permissions:"..Permission,true)
	return Table,CountTable(Table) or 0
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- AMOUNTGROUPS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.AmountGroups(Permission)
	local Amount = vRP.GetSrvData("Permissions:"..Permission,true)
	return CountTable(Amount) or 0
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GROUPTYPE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.GroupType(Permission)
	return Groups[Permission] and Groups[Permission].Type or "UnWorked"
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- LOOPPERMISSION
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.LoopPermission(Passport,Permission)
	if Groups[Permission] and Groups[Permission].Permission then
		for Parent in pairs(Groups[Permission].Permission) do
			if vRP.HasPermission(Passport,Parent) then
				return Parent
			end
		end
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PAINELBLOCK
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.PainelBlock(Permission)
	return Groups[Permission] and Groups[Permission].Block or false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GETUSERTYPE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.GetUserType(Passport,Type)
	local Passport = tostring(Passport)

	for Permission,Group in pairs(Groups) do
		if Group.Type == Type then
			local Consult = vRP.GetSrvData("Permissions:"..Permission,true)
			if Consult[Passport] then
				return Permission
			end
		end
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- HIERARCHY
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.Hierarchy(Permission)
	return Groups[Permission] and Groups[Permission].Hierarchy or {}
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- NAMEHIERARCHY
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.NameHierarchy(Permission,Level)
	return Groups[Permission] and Groups[Permission].Hierarchy and Groups[Permission].Hierarchy[Level] or Permission
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- NUMPERMISSION
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.NumPermission(Permission)
	local Table = {}
	if Groups[Permission] and Groups[Permission].Permission then
		for Parent in pairs(Groups[Permission].Permission) do
			if Service[Parent] then
				for Passport,source in pairs(Service[Parent]) do
					if source and Characters[source] and not Table[Passport] then
						Table[Passport] = source
					end
				end
			end
		end
	end

	return Table,CountTable(Table) or 0
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- NUMGROUPS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.NumGroups(Permission)
	local Table = {}
	if Groups[Permission] and Groups[Permission].Permission then
		for Parent in pairs(Groups[Permission].Permission) do
			local Players = vRP.DataGroups(Parent)
			if Groups[Parent] and Players then
				for Passport,Level in pairs(Players) do
					if not Table[Passport] then
						Table[Passport] = { Level = Level, Permission = Parent }
					end
				end
			end
		end
	end

	return Table
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- AMOUNTSERVICE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.AmountService(Permission,Level)
	local PermissionParts = splitString(Permission,"-")
	if PermissionParts[2] then
		Permission,Level = PermissionParts[1],parseInt(PermissionParts[2])
	end

	local Table = {}
	if Groups[Permission] and Groups[Permission].Permission then
		for Parent in pairs(Groups[Permission].Permission) do
			if Service[Parent] then
				for Passport,source in pairs(Service[Parent]) do
					if source and Characters[source] and not Table[Passport] and (not Level or (Level and Level == vRP.HasPermission(Passport,Parent))) then
						Table[Passport] = true
					end
				end
			end
		end
	end

	return CountTable(Table) or 0
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SERVICETOGGLE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.ServiceToggle(source,Passport,Permission,Silenced)
	if not Characters[source] then
		return false
	end

	if Groups[Permission] then
		local Passport = tostring(Passport)
		local Permission = SplitOne(Permission)
		if Service[Permission] and Service[Permission][Passport] then
			vRP.ServiceLeave(source,Passport,Permission,Silenced)
		elseif vRP.HasPermission(Passport,Permission) then
			vRP.ServiceEnter(source,Passport,Permission,Silenced)
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SERVICEENTER
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.ServiceEnter(source,Passport,Permission,Silenced)
	if not source or not Passport or not Permission or not Characters[source] or not Groups[Permission] then
		return false
	end

	local CurrentTimer = os.time()
	local Passport = tostring(Passport)
	local Level = vRP.HasPermission(Passport,Permission)

	if not Playing[Permission] then
		Playing[Permission] = {}
	end

	Playing[Permission][Passport] = Playing[Permission][Passport] or CurrentTimer

	Player(source).state[Permission] = Level

	if Groups[Permission].Markers then
		exports.markers:Enter(source,Permission,Level)
	end

	if Service[Permission] then
		Service[Permission][Passport] = source
		TriggerClientEvent("service:Client",source,Permission,true)
	end

	if not Silenced then
		TriggerClientEvent("Notify",source,"Central de Empregos","Você acaba de dar inicio a sua jornada de trabalho, lembrando que a sua vida não se resume só a isso.","default",5000)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SERVICELEAVE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.ServiceLeave(source,Passport,Permission,Silenced)
	if not Characters[source] or not Groups[Permission] then
		return false
	end

	local CurrentTimer = os.time()
	local Passport = tostring(Passport)

	if not Playing[Permission] then
		Playing[Permission] = {}
	end

	if Playing[Permission][Passport] then
		local Consult = vRP.GetSrvData("Playing:"..Passport,true)
		Consult[Permission] = (Consult[Permission] or 0) + (CurrentTimer - Playing[Permission][Passport])
		vRP.SetSrvData("Playing:"..Passport,Consult,true)

		Playing[Permission][Passport] = nil
	end

	Player(source).state[Permission] = nil

	if Groups[Permission].Markers then
		exports.markers:Exit(source,Passport)
		TriggerClientEvent("radio:RadioClean",source)
	end

	if Service[Permission] and Service[Permission][Passport] then
		TriggerClientEvent("service:Client",source,Permission,false)
		Service[Permission][Passport] = nil
	end

	if not Silenced then
		TriggerClientEvent("Notify",source,"Central de Empregos","Você acaba finalizar sua jornada de trabalho, esperamos que você tenha aprendido bastante hoje.","default",5000)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SETPERMISSION
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.SetPermission(Passport,Permission,Level,Mode)
	if Groups[Permission] then
		local Passport = tostring(Passport)
		local Consult = vRP.GetSrvData("Permissions:"..Permission,true)
		local Hierarchy = Groups[Permission].Hierarchy and CountTable(Groups[Permission].Hierarchy) or 1

		if Mode then
			local Adjustment = (Mode == "Demote") and 1 or -1
			Consult[Passport] = math.min(math.max((Consult[Passport] or 1) + Adjustment,1),Hierarchy)
		else
			Consult[Passport] = Level and math.min(parseInt(Level),Hierarchy) or Hierarchy
		end

		vRP.ServiceEnter(vRP.Source(Passport),Passport,Permission,true)
		vRP.SetSrvData("Permissions:"..Permission,Consult,true)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- REMOVEPERMISSION
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.RemovePermission(Passport,Permission)
	if Groups[Permission] then
		local Passport = tostring(Passport)
		if Service[Permission] and Service[Permission][Passport] then
			Service[Permission][Passport] = nil
		end

		local Consult = vRP.GetSrvData("Permissions:"..Permission,true)
		if Consult[Passport] then
			local source = vRP.Source(Passport)

			Consult[Passport] = nil
			vRP.ServiceLeave(source,Passport,Permission,true)
			vRP.SetSrvData("Permissions:"..Permission,Consult,true)
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- HASPERMISSION
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.HasPermission(Passport,Permission,Level)
	local PermissionParts = splitString(Permission,"-")
	if PermissionParts[2] then
		Permission,Level = PermissionParts[1],parseInt(PermissionParts[2])
	end

	if not Groups[Permission] then
		return false
	end

	local Passport = tostring(Passport)
	local Consult = vRP.GetSrvData("Permissions:"..Permission,true)
	local CurrentLevel = Consult[Passport]

	return (CurrentLevel and (not Level or CurrentLevel <= Level)) and CurrentLevel or false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- HASTABLE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.HasTable(Passport,Table)
	local Passport = tostring(Passport)

	for _,Permission in ipairs(Table) do
		local Check = splitString(Permission)
		local PermissionName,LevelParented = Check[1],Check[2] and parseInt(Check[2]) or nil
		local Consult = vRP.GetSrvData("Permissions:"..PermissionName,true)
		local CurrentLevel = Consult[Passport]

		if CurrentLevel and (not LevelParented or CurrentLevel <= LevelParented) then
			return Permission
		end
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- HASGROUP
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.HasGroup(Passport,Permission,Level)
	if not Passport or not Permission then
		return false
	end

	local PermissionParts = splitString(Permission)
	if PermissionParts[2] then
		Permission,Level = PermissionParts[1],parseInt(PermissionParts[2])
	end

	if Groups[Permission] and Groups[Permission].Permission then
		local Passport = tostring(Passport)
		for Parent in pairs(Groups[Permission].Permission) do
			local ParentParts = splitString(Parent)
			local ParentPermission,ParentLevel = ParentParts[1],ParentParts[2] and parseInt(ParentParts[2]) or nil
			local Consult = vRP.GetSrvData("Permissions:"..ParentPermission,true)
			local CurrentLevel = Consult[Passport]

			if CurrentLevel and ((not Level and not ParentLevel) or (not Level and ParentLevel and CurrentLevel == ParentLevel) or (Level and CurrentLevel <= Level)) then
				return CurrentLevel
			end
		end
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- HASSERVICE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.HasService(Passport,Permission,Level)
	local PermissionParts = splitString(Permission)
	if PermissionParts[2] then
		Permission,Level = PermissionParts[1],parseInt(PermissionParts[2])
	end

	if Groups[Permission] and Groups[Permission].Permission then
		local Passport = tostring(Passport)
		for Parent in pairs(Groups[Permission].Permission) do
			local ParentParts = splitString(Parent)
			local ParentPermission,ParentLevel = ParentParts[1],ParentParts[2] and parseInt(ParentParts[2]) or nil
			local Consult = vRP.GetSrvData("Permissions:"..ParentPermission,true)
			local CurrentLevel = Consult[Passport]

			if CurrentLevel and Groups[ParentPermission] and Service[ParentPermission] and Service[ParentPermission][Passport] then
				if (not Level and not ParentLevel) or (not Level and ParentLevel and CurrentLevel == ParentLevel) or (Level and CurrentLevel <= Level) then
					return CurrentLevel
				end
			end
		end
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYING
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.Playing(Passport,Permission)
	local CurrentTimer = os.time()
	local Passport = tostring(Passport)
	local Consult = vRP.GetSrvData("Playing:"..Passport)
	local Return = Consult[Permission] or 0

	if Playing[Permission] and Playing[Permission][Passport] then
		Return = Return + (CurrentTimer - Playing[Permission][Passport])
	end

	return Return
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Connect",function(Passport,source,First)
	local Passport = tostring(Passport)
	for Permission,v in pairs(Groups) do
		if v.Service and vRP.HasPermission(Passport,Permission) and Service[Permission] and (Service[Permission][Passport] == false or (First and Service[Permission][Passport] == nil)) then
			vRP.ServiceEnter(source,Passport,Permission,true)
		end
	end

	Playing.Online[Passport] = Playing.Online[Passport] or os.time()
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport,source)
	local CurrentTimer = os.time()
	local Passport = tostring(Passport)
	local Consult = vRP.GetSrvData("Playing:"..Passport,true)

	for Permission,v in pairs(Groups) do
		if Playing[Permission] and Playing[Permission][Passport] then
			Consult[Permission] = (Consult[Permission] or 0) + (CurrentTimer - Playing[Permission][Passport])
			Playing[Permission][Passport] = nil
		end

		if Service[Permission] and Service[Permission][Passport] then
			Service[Permission][Passport] = false
		end
	end

	if Playing.Online[Passport] then
		Consult.Online = (Consult.Online or 0) + (CurrentTimer - Playing.Online[Passport])
		Playing.Online[Passport] = nil
	end

	vRP.SetSrvData("Playing:"..Passport,Consult,true)
end)