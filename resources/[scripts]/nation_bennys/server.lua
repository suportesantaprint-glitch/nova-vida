-----------------------------------------------------------------------------------------------------------------------------------------
-- FloripaGroup - nation_bennys (SERVER)
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- INTERFACE
-----------------------------------------------------------------------------------------------------------------------------------------
local bennys = {}
Tunnel.bindInterface("nation_bennys", bennys)

-----------------------------------------------------------------------------------------------------------------------------------------
-- PREPARES (DB por PLACA)
-- (Se você já tiver em outro arquivo, pode remover daqui)
-----------------------------------------------------------------------------------------------------------------------------------------
vRP._Prepare("bennys/SetModsByPlate", [[
  INSERT INTO bennys_vehicle_mods (plate, mods)
  VALUES (@plate, @mods)
  ON DUPLICATE KEY UPDATE mods = VALUES(mods)
]])

vRP._Prepare("bennys/GetModsByPlate", [[
  SELECT mods FROM bennys_vehicle_mods WHERE plate = @plate
]])

vRP._Prepare("bennys/DeleteModsByPlate", [[
  DELETE FROM bennys_vehicle_mods WHERE plate = @plate
]])

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function normalizePlate(plate)
  if not plate then return "" end
  plate = tostring(plate)
  plate = plate:gsub("%s+","") -- remove espaços
  return plate
end

local function safeEncode(tbl)
  local ok, encoded = pcall(json.encode, tbl)
  if ok and encoded and encoded ~= "" then return encoded end
  return "{}"
end

local function safeDecode(str)
  if not str or str == "" then return nil end
  local ok, decoded = pcall(json.decode, str)
  if ok then return decoded end
  return nil
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- SALVAR/PEGAR MODS POR PLACA (DB)
-----------------------------------------------------------------------------------------------------------------------------------------
function bennys.SaveModsByPlate(plate, mods)
  local source = source
  local Passport = vRP.Passport(source)
  if not Passport then return false end
  plate = normalizePlate(plate)
  if plate == "" then return false end
  if type(mods) ~= "table" then return false end

  -- Garantir que neon seja um array ou valor válido
  if mods.neon and type(mods.neon) == "boolean" then
    mods.neon = {false, false, false, false} -- Ajuste para garantir a estrutura correta
  end

  local ok, encoded = pcall(json.encode, mods)
  if not ok or not encoded or encoded == "" then
    return false
  end

  -- Armazenar os mods no banco de dados
  vRP.Query("bennys/SetModsByPlate", { plate = plate, mods = encoded })
  return true
end

function bennys.GetModsByPlate(plate)
  plate = normalizePlate(plate)
  if plate == "" then return nil end

  local rows = vRP.Query("bennys/GetModsByPlate", { plate = plate })
  if rows and rows[1] and rows[1].mods then
    local ok, decoded = pcall(json.decode, rows[1].mods)
    if ok then
      -- Garantir que neon tenha estrutura válida ao ser retornado
      if decoded.neon and type(decoded.neon) == "boolean" then
        decoded.neon = {false, false, false, false} -- Ajuste para garantir a estrutura correta
      end
      return decoded
    end
  end
  return nil
end


function bennys.DeleteModsByPlate(plate)
  plate = normalizePlate(plate)
  if plate == "" then return false end
  vRP.Query("bennys/DeleteModsByPlate", { plate = plate })
  return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- PERMISSÃO
-----------------------------------------------------------------------------------------------------------------------------------------
function bennys.checkPermission()
  local source = source
  local passport = vRP.Passport(source)
  if not passport then return false end

  if config and config.permissao and config.permissao ~= "" then
    if vRP.HasPermission then
      return vRP.HasPermission(passport, config.permissao)
    end
  end

  return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- VALIDAÇÃO DO VEÍCULO (mantido)
-----------------------------------------------------------------------------------------------------------------------------------------
function bennys.checkVehicle(netId)
  if not netId then return false end
  return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- PAGAMENTO (mantido)
-----------------------------------------------------------------------------------------------------------------------------------------
function bennys.checkPayment(amount)
  local source = source
  local passport = vRP.Passport(source)
  if not passport then return false end

  amount = tonumber(amount) or 0
  if amount <= 0 then return true end

  if vRP.PaymentFull then
    return vRP.PaymentFull(passport, amount)
  end

  if vRP.TryFullPayment then
    return vRP.TryFullPayment(passport, amount)
  end

  return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- LEGADO (entitydata) - mantém compatibilidade com sua garagem antiga
-----------------------------------------------------------------------------------------------------------------------------------------
function bennys.saveVehicle(vehName, vehPlate, myveh)
  local source = source
  local passport = vRP.Passport(source)
  if not passport then return false end
  if not vehName or vehName == "" then return false end

  local dkey = "Mods:" .. passport .. ":" .. vehName
  local dvalue = safeEncode(myveh or {})

  vRP.Query("entitydata/SetData", { dkey = dkey, dvalue = dvalue })
  return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- REPAIR / REMOVE (compatibilidade)
-----------------------------------------------------------------------------------------------------------------------------------------
function bennys.repairVehicle(vehicle, damage)
  return true
end

function bennys.removeVehicle(netId)
  return true
end
