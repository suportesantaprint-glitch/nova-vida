-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATEDAILY
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.UpdateDaily(Passport,source,Daily)
    exports.oxmysql:execute("UPDATE characters SET Daily = @Daily WHERE id = @Passport",{ Daily = Daily, Passport = Passport })

    if Characters[source] then
        Characters[source].Daily = Daily
    end
end