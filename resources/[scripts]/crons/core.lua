-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Jobs = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- EXECUTE
-----------------------------------------------------------------------------------------------------------------------------------------
local function Execute(Job)
  if not Job or not Job.Params then return end

  if Job.Mode == "RemovePermission" and Job.Params.Permission then
    vRP.RemovePermission(Job.Passport,Job.Params.Permission)
  elseif Job.Mode == "WipePermission" and Job.Params.Permission then
    vRP.RemSrvData("Permissions:" .. Job.Params.Permission)
  elseif Job.Mode == "RemoveVehicle" and Job.Params.Model then
    vRP.RemSrvData("LsCustoms:" .. Job.Passport .. ":" .. Job.Params.Model)
    vRP.RemSrvData("Trunkchest:" .. Job.Passport .. ":" .. Job.Params.Model)
    vRP.Query("vehicles/removeVehicles",{ Passport = Job.Passport, Vehicle = Job.Params.Model })
  end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INSERT
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Insert",function(Passport,Mode,Timer,Params)
  Timer = Timer * 60

  local Updated = false
  for _,v in ipairs(Jobs) do
    if v.Passport == Passport and v.Mode == Mode then
      if (Mode == "RemovePermission" and v.Params.Permission == Params.Permission) or
         (Mode == "RemoveVehicle" and v.Params.Model == Params.Model) or
         (Mode == "WipePermission" and v.Params.Permission == Params.Permission) then
        v.Timer = v.Timer + Timer
        Updated = true
        break
      end
    end
  end

  if not Updated then
    table.insert(Jobs,{ Timer = os.time() + Timer, Passport = Passport, Params = Params, Mode = Mode })
  end

  SaveResourceFile(GetCurrentResourceName(),"config.json",json.encode(Jobs,{ indent = true }),-1)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SWAP
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Swap",function(Passport,NewPassport)
  for _,v in ipairs(Jobs) do
    if v.Passport == Passport then
      v.Passport = NewPassport
    end
  end

  SaveResourceFile(GetCurrentResourceName(),"config.json",json.encode(Jobs,{ indent = true }),-1)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- REMOVE
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Remove",function(Passport,Mode,Param)
  for i = #Jobs,1,-1 do
    local Job = Jobs[i]

    if Job.Passport == Passport and Job.Mode == Mode then
      if (Mode == "RemovePermission" and Job.Params.Permission == Param) or
          (Mode == "RemoveVehicle" and Job.Params.Model == Param) or
          (Mode == "WipePermission" and Job.Params.Permission == Param) then
        table.remove(Jobs,i)
      end
    end
  end

  SaveResourceFile(GetCurrentResourceName(),"config.json",json.encode(Jobs,{ indent = true }),-1)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECK
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Check",function(Passport,Mode,Params)
  for _,v in ipairs(Jobs) do
    if v.Passport == Passport and v.Mode == Mode then
      if (Mode == "RemovePermission" and v.Params.Permission == Params.Permission) or
          (Mode == "RemoveVehicle" and v.Params.Model == Params.Model) or
          (Mode == "WipePermission" and v.Params.Permission == Params.Permission) then
        return v.Timer - os.time()
      end
    end
  end

  return false
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSERVERSTART
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
  local Content = LoadResourceFile(GetCurrentResourceName(),"config.json")
  Jobs = json.decode(Content or "{}")

  while true do
    local CurrentTime = os.time()

    for i = #Jobs,1,-1 do
      local Job = Jobs[i]
      if Job.Timer <= CurrentTime then
        table.remove(Jobs,i)
        Execute(Job)
      end
    end

    Wait(600000)
  end
end)