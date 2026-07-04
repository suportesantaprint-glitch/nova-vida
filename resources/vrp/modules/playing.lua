-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Played = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATEPLAYING
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.UpdatePlaying(Passport,Timer)
    Timer = Timer or 0

    local Consult = vRP.GetSrvData("Playing:"..Passport,true)
    Consult.Online = (Consult.Online or 0) + (Timer - (Playing.Online[Passport] or 0))
    vRP.SetSrvData("Playing:"..Passport,Consult,true)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TIMEPLAYING
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.TimePlaying(Passport)
    local Consult = vRP.GetSrvData("Playing:"..Passport,true)
    return Consult.Online or 0
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- WIPEPLAYING
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.WipePlaying()    
    return exports.oxmysql:query_async("UPDATE characters SET Killed = 0, Death = 0", {})
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADPLAYED
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
    local Timer = os.time()

    while true do
        Wait(10000)
        local Players = vRP.Players()

        for Passport, _ in pairs(Players) do
            Played[Passport] = (Played[Passport] or 0) + (os.time() - Timer)
        end

        if os.time() - Timer >= 1 then
            for Passport, Seconds in pairs(Played) do
                if Seconds > 0 then
                    vRP.UpdatePlaying(Passport,Seconds)
                    Played[Passport] = 0
                end
            end
            Timer = os.time()
        end
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Connect",function(Passport,source,First)
	local Passport = tostring(Passport)
    
    if not Playing.Online then
		Playing.Online = {}
	end

	Playing.Online[Passport] = Playing.Online[Passport] or os.time()
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect", function(Passport)
	local CurrentTimer = os.time()
	local Passport = tostring(Passport)
	local Consult = vRP.GetSrvData("Playing:"..Passport,true)
	
    if Playing.Online and Playing.Online[Passport] then
		Consult.Online = (Consult.Online or 0) + (CurrentTimer - Playing.Online[Passport])
		Playing.Online[Passport] = nil
	end
	
    if Playing[Passport] and Playing[Passport] > 0 then
        vRP.UpdatePlaying(Passport, Playing[Passport])
        Playing[Passport] = nil
    end

	vRP.SetSrvData("Playing:"..Passport,Consult,true)
end)