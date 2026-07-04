-----------------------------------------------------------------------------------------------------------------------------------------
-- PERMISSIONS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.Permissions(Permission, Column)
    local Consult = exports.oxmysql:single_async("SELECT * FROM permissions WHERE Permission = @Permission LIMIT 1", { Permission = Permission })
    if not Consult then
        exports.oxmysql:query_async("INSERT INTO permissions (Permission, Tags, Announces) VALUES (@Permission, 3, 3)", { Permission = Permission })
        Consult = {}
    end

    local Default = {
        Members = 10,
        Experience = 0,
        Points = 0,
        Bank = 0,
        Premium = 0,
        Tags = 3,
        Announces = 3
    }

    if Column == "Premium" then
        return tonumber(Consult[Column]) or Default[Column]
    end

    return Consult[Column] and tonumber(Consult[Column]) or Default[Column] or 0
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PERMISSIONSUPDATE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.PermissionsUpdate(Permission,Column,Mode,Amount)
    local Consult = exports.oxmysql:single_async("SELECT * FROM permissions WHERE Permission = @Permission LIMIT 1", { Permission = Permission })
    if not Consult then
        exports.oxmysql:query_async("INSERT INTO permissions (Permission, Tags, Announces) VALUES (@Permission, 3, 3)", { Permission = Permission })
    end

    if Column == "Premium" then
        local Premium
        if Mode == "+" then
            Premium = tonumber(Amount)
        else
            local Current = tonumber(Consult.Premium) or 0
            Premium = math.max(Current - tonumber(Amount), 0)
        end

        exports.oxmysql:query_async("UPDATE permissions SET Premium = @Value WHERE Permission = @Permission", { Permission = Permission, Value = Premium })
        return
    end

	if not Contains({ "Members","Experience","Premium","Points","Bank" },Column) then
		return
	end

	local Operation = Mode == "+" and "+" or "-"
	local Query = string.format("UPDATE permissions SET %s = GREATEST(%s %s @Amount, 0) WHERE Permission = @Permission",Column,Column,Operation)
    exports.oxmysql:query_async(Query,{ Permission = Permission, Amount = parseInt(Amount) })
end