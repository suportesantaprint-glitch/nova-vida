local L0_1, L1_1, L2_1, L3_1, L4_1, L5_1, L6_1, L7_1, L8_1
L0_1 = {}
Elevator = L0_1
L0_1 = Elevator
function L1_1(A0_2, A1_2, A2_2, A3_2, A4_2, A5_2, A6_2, A7_2, A8_2, A9_2, A10_2)
  local L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2, L19_2
  L11_2 = GetHashKey
  L12_2 = A4_2
  L11_2 = L11_2(L12_2)
  L12_2 = RequestModel
  L13_2 = L11_2
  L12_2(L13_2)
  while true do
    L12_2 = HasModelLoaded
    L13_2 = L11_2
    L12_2 = L12_2(L13_2)
    if L12_2 then
      break
    end
    L12_2 = RequestModel
    L13_2 = L11_2
    L12_2(L13_2)
    L12_2 = Citizen
    L12_2 = L12_2.Wait
    L13_2 = 1
    L12_2(L13_2)
  end
  L12_2 = CreateObject
  L13_2 = L11_2
  L14_2 = A5_2.x
  L15_2 = A5_2.y
  L16_2 = A5_2.z
  L17_2 = A8_2 or L17_2
  if not A8_2 then
    L17_2 = 1
  end
  L17_2 = A7_2[L17_2]
  L17_2 = L17_2.z
  L16_2 = L16_2 + L17_2
  L17_2 = false
  L18_2 = true
  L19_2 = false
  L12_2 = L12_2(L13_2, L14_2, L15_2, L16_2, L17_2, L18_2, L19_2)
  L13_2 = DoesEntityExist
  L14_2 = L12_2
  L13_2 = L13_2(L14_2)
  if L13_2 then
    L13_2 = GetEntityCoords
    L14_2 = L12_2
    L13_2 = L13_2(L14_2)
    L14_2 = FreezeEntityPosition
    L15_2 = L12_2
    L16_2 = true
    L14_2(L15_2, L16_2)
    L14_2 = SetEntityInvincible
    L15_2 = L12_2
    L16_2 = true
    L14_2(L15_2, L16_2)
    L14_2 = SetEntityHeading
    L15_2 = L12_2
    L16_2 = A6_2 + 0.0
    L14_2(L15_2, L16_2)
    L14_2 = SetEntityAlwaysPrerender
    L15_2 = L12_2
    L16_2 = true
    L14_2(L15_2, L16_2)
    L14_2 = SetModelAsNoLongerNeeded
    L15_2 = hashKey
    L14_2(L15_2)
    L14_2 = {}
    L14_2.id = A1_2
    L14_2.name = A2_2
    L14_2.text = A3_2
    L14_2.model = A4_2
    L14_2.position = A5_2
    L14_2.heading = A6_2
    L14_2.floors = A7_2
    L14_2.menu = A9_2
    L15_2 = {}
    L16_2 = A10_2 or L16_2
    if A10_2 then
      L16_2 = A10_2.msec
    end
    if not L16_2 then
      L16_2 = 50
    end
    L15_2.msec = L16_2
    L16_2 = A10_2 or L16_2
    if A10_2 then
      L16_2 = A10_2.z
    end
    if not L16_2 then
      L16_2 = 0.03
    end
    L15_2.z = L16_2
    L14_2.speed = L15_2
    L14_2.entity = L12_2
    L15_2 = A8_2 or L15_2
    if not A8_2 then
      L15_2 = 1
    end
    L14_2.current = L15_2
    L14_2.pivot = L13_2
    L15_2 = setmetatable
    L16_2 = L14_2
    L17_2 = A0_2
    L15_2(L16_2, L17_2)
    A0_2.__index = A0_2
    return L14_2
  end
end
L0_1.create = L1_1
L0_1 = RequestScriptAudioBank
L1_1 = "SCRIPT/LIFTS"
L2_1 = false
L0_1(L1_1, L2_1)
L0_1 = GetSoundId
L0_1 = L0_1()
L1_1 = Elevator
function L2_1(A0_2, A1_2, A2_2)
  local L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2
  L3_2 = PlaySoundFrontend
  L4_2 = -1
  L5_2 = "BUTTON"
  L6_2 = "MP_PROPERTIES_ELEVATOR_DOORS"
  L7_2 = 1
  L3_2(L4_2, L5_2, L6_2, L7_2)
  L3_2 = DoesEntityExist
  L4_2 = A0_2.entity
  L3_2 = L3_2(L4_2)
  if L3_2 then
    L3_2 = A0_2.floors
    L3_2 = L3_2[A1_2]
    if L3_2 then
      A0_2.moviment = true
      L3_2 = GetEntityCoords
      L4_2 = A0_2.entity
      L3_2 = L3_2(L4_2)
      L4_2 = A0_2.pivot
      L4_2 = L4_2.z
      L5_2 = A0_2.floors
      L5_2 = L5_2[A1_2]
      L5_2 = L5_2.z
      L4_2 = L4_2 + L5_2
      L5_2 = GetSoundId
      L5_2 = L5_2()
      L0_1 = L5_2
      L5_2 = PlaySoundFromEntity
      L6_2 = L0_1
      L7_2 = "Move"
      L8_2 = A0_2.entity
      L9_2 = "LIFT_NORMAL_SOUNDSET"
      L10_2 = true
      L5_2(L6_2, L7_2, L8_2, L9_2, L10_2)
      L5_2 = ReleaseSoundId
      L6_2 = L0_1
      L5_2(L6_2)
      if A2_2 then
        L5_2 = SetEntityCoords
        L6_2 = A0_2.entity
        L7_2 = L3_2.x
        L8_2 = L3_2.y
        L9_2 = L4_2
        L5_2(L6_2, L7_2, L8_2, L9_2)
        A0_2.current = A1_2
        A0_2.moviment = false
        L5_2 = true
        return L5_2
      else
        L5_2 = L3_2.z
        if L4_2 > L5_2 then
          while true do
            L5_2 = L3_2.z
            if not (L4_2 > L5_2) then
              break
            end
            L5_2 = vec3
            L6_2 = 0
            L7_2 = 0
            L8_2 = A0_2.speed
            L8_2 = L8_2.z
            L5_2 = L5_2(L6_2, L7_2, L8_2)
            L3_2 = L3_2 + L5_2
            L5_2 = SetEntityCoords
            L6_2 = A0_2.entity
            L7_2 = L3_2.x
            L8_2 = L3_2.y
            L9_2 = L3_2.z
            L5_2(L6_2, L7_2, L8_2, L9_2)
            L5_2 = Wait
            L6_2 = A0_2.speed
            L6_2 = L6_2.msec
            L5_2(L6_2)
          end
          A0_2.current = A1_2
          A0_2.moviment = false
          L5_2 = PlaySoundFromEntity
          L6_2 = -1
          L7_2 = "Tone"
          L8_2 = A0_2.entity
          L9_2 = "LIFT_NORMAL_SOUNDSET"
          L10_2 = true
          L5_2(L6_2, L7_2, L8_2, L9_2, L10_2)
          L5_2 = StopSound
          L6_2 = L0_1
          L5_2(L6_2)
          L5_2 = true
          return L5_2
        else
          while true do
            L5_2 = L3_2.z
            if not (L4_2 < L5_2) then
              break
            end
            L5_2 = vec3
            L6_2 = 0
            L7_2 = 0
            L8_2 = A0_2.speed
            L8_2 = L8_2.z
            L5_2 = L5_2(L6_2, L7_2, L8_2)
            L3_2 = L3_2 - L5_2
            L5_2 = SetEntityCoords
            L6_2 = A0_2.entity
            L7_2 = L3_2.x
            L8_2 = L3_2.y
            L9_2 = L3_2.z
            L5_2(L6_2, L7_2, L8_2, L9_2)
            L5_2 = Wait
            L6_2 = A0_2.speed
            L6_2 = L6_2.msec
            L5_2(L6_2)
          end
          A0_2.current = A1_2
          A0_2.moviment = false
          L5_2 = PlaySoundFromEntity
          L6_2 = -1
          L7_2 = "Tone"
          L8_2 = A0_2.entity
          L9_2 = "LIFT_NORMAL_SOUNDSET"
          L10_2 = true
          L5_2(L6_2, L7_2, L8_2, L9_2, L10_2)
          L5_2 = StopSound
          L6_2 = L0_1
          L5_2(L6_2)
          L5_2 = true
          return L5_2
        end
      end
      A0_2.moviment = false
    end
  end
end
L1_1.setFloor = L2_1
L1_1 = Elevator
function L2_1(A0_2)
  local L1_2, L2_2
  L1_2 = DoesEntityExist
  L2_2 = A0_2.entity
  L1_2 = L1_2(L2_2)
  if L1_2 then
    L1_2 = A0_2.current
    return L1_2
  end
end
L1_1.getFloor = L2_1
L1_1 = Elevator
function L2_1(A0_2, A1_2)
  local L2_2, L3_2
  L2_2 = DoesEntityExist
  L3_2 = A0_2.entity
  L2_2 = L2_2(L3_2)
  if L2_2 then
    L2_2 = A0_2.floors
    L2_2 = L2_2[A1_2]
    L2_2 = nil ~= L2_2
    return L2_2
  end
end
L1_1.isFloorValid = L2_1
L1_1 = Elevator
function L2_1(A0_2)
  local L1_2, L2_2
  L1_2 = DoesEntityExist
  L2_2 = A0_2.entity
  L1_2 = L1_2(L2_2)
  if L1_2 then
    L1_2 = A0_2.moviment
    return L1_2
  end
end
L1_1.inMoviment = L2_1
L1_1 = Elevator
function L2_1(A0_2)
  local L1_2, L2_2
  L1_2 = DoesEntityExist
  L2_2 = A0_2.entity
  L1_2 = L1_2(L2_2)
  if L1_2 then
    L1_2 = GetEntityCoords
    L2_2 = A0_2.entity
    L1_2 = L1_2(L2_2)
    L2_2 = A0_2.menu
    L2_2 = L1_2 + L2_2
    return L2_2
  end
end
L1_1.getMenuCoords = L2_1
L1_1 = Elevator
function L2_1(A0_2)
  local L1_2, L2_2
  L1_2 = DoesEntityExist
  L2_2 = A0_2.entity
  L1_2 = L1_2(L2_2)
  if L1_2 then
    L1_2 = A0_2.name
    L2_2 = A0_2.floors
    return L1_2, L2_2
  end
end
L1_1.getInfo = L2_1
L1_1 = {}
L2_1 = vec3
L3_1 = 0
L4_1 = 0
L5_1 = 0
L2_1 = L2_1(L3_1, L4_1, L5_1)
L3_1 = {}
L3_1.count = 0
L4_1 = false
L5_1 = AddEventHandler
L6_1 = "onResourceStop"
function L7_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2
  L1_2 = GetCurrentResourceName
  L1_2 = L1_2()
  if A0_2 == L1_2 then
    L1_2 = pairs
    L2_2 = L1_1
    L1_2, L2_2, L3_2, L4_2 = L1_2(L2_2)
    for L5_2, L6_2 in L1_2, L2_2, L3_2, L4_2 do
      L7_2 = DoesEntityExist
      L8_2 = L6_2.entity
      L7_2 = L7_2(L8_2)
      if L7_2 then
        L7_2 = DeleteEntity
        L8_2 = L6_2.entity
        L7_2(L8_2)
      end
    end
  end
end
L5_1(L6_1, L7_1)
L5_1 = config
L5_1 = L5_1.elevator
if L5_1 then
  L5_1 = Citizen
  L5_1 = L5_1.CreateThread
  function L6_1()
    local L0_2, L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2
    L0_2 = RequestScriptAudioBank
    L1_2 = "SCRIPT/LIFTS"
    L2_2 = false
    L0_2(L1_2, L2_2)
    L0_2 = {}
    L1_2 = {}
    L2_2 = config
    L2_2 = L2_2.lang
    L2_2 = L2_2.name
    L1_2.name = L2_2
    L2_2 = config
    L2_2 = L2_2.lang
    L2_2 = L2_2.mainText
    L1_2.mainText = L2_2
    L1_2.model = "maibnx_rest_asylum_elevator"
    L2_2 = vec3
    L3_2 = 3948.58813
    L4_2 = 4887.19629
    L5_2 = 13.8919844
    L2_2 = L2_2(L3_2, L4_2, L5_2)
    L1_2.position = L2_2
    L1_2.heading = 110.0
    L1_2.default_floor = 4
    L2_2 = {}
    L3_2 = vec3
    L4_2 = -2.7
    L5_2 = 0.2
    L6_2 = -1.5
    L3_2 = L3_2(L4_2, L5_2, L6_2)
    L2_2.menu = L3_2
    L3_2 = {}
    L4_2 = {}
    L4_2.z = 17.7
    L5_2 = config
    L5_2 = L5_2.lang
    L5_2 = L5_2.floors
    L5_2 = L5_2["4th"]
    L4_2.text = L5_2
    L5_2 = {}
    L5_2.z = 11.6
    L6_2 = config
    L6_2 = L6_2.lang
    L6_2 = L6_2.floors
    L6_2 = L6_2["3rd"]
    L5_2.text = L6_2
    L6_2 = {}
    L6_2.z = 5.5
    L7_2 = config
    L7_2 = L7_2.lang
    L7_2 = L7_2.floors
    L7_2 = L7_2["2nd"]
    L6_2.text = L7_2
    L7_2 = {}
    L7_2.z = 0.0
    L8_2 = config
    L8_2 = L8_2.lang
    L8_2 = L8_2.floors
    L8_2 = L8_2["1st"]
    L7_2.text = L8_2
    L8_2 = {}
    L8_2.z = -8.4
    L9_2 = config
    L9_2 = L9_2.lang
    L9_2 = L9_2.floors
    L9_2 = L9_2.ground
    L8_2.text = L9_2
    L3_2[1] = L4_2
    L3_2[2] = L5_2
    L3_2[3] = L6_2
    L3_2[4] = L7_2
    L3_2[5] = L8_2
    L2_2.floors = L3_2
    L1_2.offsets = L2_2
    L2_2 = {}
    L2_2.msec = 20
    L2_2.z = 0.02
    L1_2.speed = L2_2
    L0_2[1] = L1_2
    L1_2 = pairs
    L2_2 = L0_2
    L1_2, L2_2, L3_2, L4_2 = L1_2(L2_2)
    for L5_2, L6_2 in L1_2, L2_2, L3_2, L4_2 do
      L7_2 = Elevator
      L8_2 = L7_2
      L7_2 = L7_2.create
      L9_2 = L5_2
      L10_2 = L6_2.name
      L11_2 = L6_2.mainText
      L12_2 = L6_2.model
      L13_2 = L6_2.position
      L14_2 = L6_2.heading
      L15_2 = L6_2.offsets
      L15_2 = L15_2.floors
      L16_2 = L6_2.default_floor
      L17_2 = L6_2.offsets
      L17_2 = L17_2.menu
      L18_2 = L6_2.speed
      L7_2 = L7_2(L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2)
      if L7_2 then
        L8_2 = L1_1
        L8_2[L5_2] = L7_2
      end
    end
    L1_2 = TriggerServerEvent
    L2_2 = "elevators:request"
    L1_2(L2_2)
    while true do
      L1_2 = GetEntityCoords
      L2_2 = PlayerPedId
      L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2 = L2_2()
      L1_2 = L1_2(L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2)
      L2_1 = L1_2
      L1_2 = pairs
      L2_2 = L1_1
      L1_2, L2_2, L3_2, L4_2 = L1_2(L2_2)
      for L5_2, L6_2 in L1_2, L2_2, L3_2, L4_2 do
        L8_2 = L6_2
        L7_2 = L6_2.getMenuCoords
        L7_2 = L7_2(L8_2)
        if L7_2 then
          L8_2 = L2_1
          L8_2 = L7_2 - L8_2
          L8_2 = #L8_2
          if L8_2 <= 50.0 then
            L9_2 = L3_1
            L9_2 = L9_2[L5_2]
            if nil == L9_2 then
              L9_2 = L3_1
              L9_2[L5_2] = L6_2
              L9_2 = L3_1.count
              L9_2 = L9_2 + 1
              L3_1.count = L9_2
            end
          else
            L9_2 = L3_1
            L9_2 = L9_2[L5_2]
            if nil ~= L9_2 then
              L9_2 = L3_1
              L9_2[L5_2] = nil
              L9_2 = L3_1.count
              L9_2 = L9_2 - 1
              L3_1.count = L9_2
            end
          end
        end
      end
      L1_2 = L3_1.count
      if L1_2 > 0 then
        L1_2 = markerThread
        L1_2()
      end
      L1_2 = Citizen
      L1_2 = L1_2.Wait
      L2_2 = 1000
      L1_2(L2_2)
    end
  end
  L5_1(L6_1)
end
L5_1 = false
function L6_1()
  local L0_2, L1_2
  L0_2 = L5_1
  if not L0_2 then
    L0_2 = true
    L5_1 = L0_2
    L0_2 = Citizen
    L0_2 = L0_2.CreateThread
    function L1_2()
      local L0_3, L1_3, L2_3, L3_3, L4_3, L5_3, L6_3, L7_3, L8_3, L9_3, L10_3, L11_3, L12_3, L13_3, L14_3, L15_3, L16_3, L17_3, L18_3, L19_3, L20_3, L21_3, L22_3, L23_3, L24_3, L25_3, L26_3, L27_3, L28_3, L29_3, L30_3, L31_3, L32_3, L33_3, L34_3
      L0_3 = {}
      L0_3.count = 0
      L1_3 = false
      while true do
        L2_3 = L3_1.count
        if not (L2_3 > 0) then
          break
        end
        L2_3 = pairs
        L3_3 = L3_1
        L2_3, L3_3, L4_3, L5_3 = L2_3(L3_3)
        for L6_3, L7_3 in L2_3, L3_3, L4_3, L5_3 do
          if "count" ~= L6_3 then
            L9_3 = L7_3
            L8_3 = L7_3.getMenuCoords
            L8_3 = L8_3(L9_3)
            if L8_3 then
              L10_3 = L7_3
              L9_3 = L7_3.inMoviment
              L9_3 = L9_3(L10_3)
              if not L9_3 then
                L9_3 = SetEntityCoords
                L10_3 = L7_3.entity
                L11_3 = GetEntityCoords
                L12_3 = L7_3.entity
                L11_3, L12_3, L13_3, L14_3, L15_3, L16_3, L17_3, L18_3, L19_3, L20_3, L21_3, L22_3, L23_3, L24_3, L25_3, L26_3, L27_3, L28_3, L29_3, L30_3, L31_3, L32_3, L33_3, L34_3 = L11_3(L12_3)
                L9_3(L10_3, L11_3, L12_3, L13_3, L14_3, L15_3, L16_3, L17_3, L18_3, L19_3, L20_3, L21_3, L22_3, L23_3, L24_3, L25_3, L26_3, L27_3, L28_3, L29_3, L30_3, L31_3, L32_3, L33_3, L34_3)
                L9_3 = L2_1
                L9_3 = L8_3 - L9_3
                L9_3 = #L9_3
                if L9_3 < 2 then
                  L10_3 = config
                  L10_3 = L10_3.drawElevatorMarker
                  if L10_3 then
                    L10_3 = DrawMarker
                    L11_3 = 23
                    L12_3 = L8_3.x
                    L13_3 = L8_3.y
                    L14_3 = L8_3.z
                    L15_3 = 0.0
                    L16_3 = 0.0
                    L17_3 = 0.0
                    L18_3 = 0.0
                    L19_3 = 0.0
                    L20_3 = 0.0
                    L21_3 = 1.0
                    L22_3 = 1.0
                    L23_3 = 1.0
                    L24_3 = 255
                    L25_3 = 255
                    L26_3 = 255
                    L27_3 = 255
                    L28_3 = false
                    L29_3 = false
                    L30_3 = 2
                    L31_3 = true
                    L32_3 = nil
                    L33_3 = nil
                    L34_3 = false
                    L10_3(L11_3, L12_3, L13_3, L14_3, L15_3, L16_3, L17_3, L18_3, L19_3, L20_3, L21_3, L22_3, L23_3, L24_3, L25_3, L26_3, L27_3, L28_3, L29_3, L30_3, L31_3, L32_3, L33_3, L34_3)
                  end
                  L10_3 = IsControlJustPressed
                  L11_3 = 1
                  L12_3 = 51
                  L10_3 = L10_3(L11_3, L12_3)
                  if L10_3 then
                    L11_3 = L7_3
                    L10_3 = L7_3.getInfo
                    L10_3, L11_3 = L10_3(L11_3)
                    if L10_3 and L11_3 then
                      L12_3 = SetNuiFocus
                      L13_3 = true
                      L14_3 = true
                      L12_3(L13_3, L14_3)
                      L12_3 = PlaySoundFrontend
                      L13_3 = -1
                      L14_3 = "BUTTON"
                      L15_3 = "MP_PROPERTIES_ELEVATOR_DOORS"
                      L16_3 = 1
                      L12_3(L13_3, L14_3, L15_3, L16_3)
                      L12_3 = SendNUIMessage
                      L13_3 = {}
                      L13_3.action = "OPEN_NUI"
                      L13_3.id = L6_3
                      L14_3 = L7_3.name
                      L13_3.name = L14_3
                      L14_3 = L7_3.text
                      L13_3.text = L14_3
                      L14_3 = L7_3.floors
                      L13_3.floors = L14_3
                      L14_3 = config
                      L14_3 = L14_3.visual
                      L13_3.visual = L14_3
                      L12_3(L13_3)
                    end
                  end
                end
              end
            end
            L9_3 = L7_3.position
            L9_3 = L9_3.xy
            L10_3 = L2_1.xy
            L9_3 = L9_3 - L10_3
            L9_3 = #L9_3
            if L9_3 <= 4.0 then
              L10_3 = L2_1.z
              L11_3 = 1.4
              if L10_3 > L11_3 then
                L10_3 = L2_1.z
                L11_3 = 45.42
                if L10_3 < L11_3 then
                  L10_3 = L0_3[L6_3]
                  if nil == L10_3 then
                    L0_3[L6_3] = L7_3
                    L10_3 = L0_3.count
                    L10_3 = L10_3 + 1
                    L0_3.count = L10_3
                  end
              end
            end
            else
              L10_3 = L0_3[L6_3]
              if nil ~= L10_3 then
                L0_3[L6_3] = nil
                L10_3 = L0_3.count
                L10_3 = L10_3 - 1
                L0_3.count = L10_3
              end
            end
          end
        end
        L2_3 = L0_3.count
        if L2_3 > 0 then
          if not L1_3 then
            L1_3 = true
            L2_3 = SetEmitterProbeLength
            L3_3 = 150.0
            L2_3(L3_3)
            L2_3 = SetInteriorProbeLength
            L3_3 = 150.0
            L2_3(L3_3)
          end
        elseif L1_3 then
          L1_3 = false
          L2_3 = SetEmitterProbeLength
          L3_3 = 20.0
          L2_3(L3_3)
          L2_3 = SetInteriorProbeLength
          L3_3 = 0.0
          L2_3(L3_3)
        end
        L2_3 = Citizen
        L2_3 = L2_3.Wait
        L3_3 = 1
        L2_3(L3_3)
      end
      L2_3 = false
      L5_1 = L2_3
      L2_3 = SetEmitterProbeLength
      L3_3 = 20.0
      L2_3(L3_3)
      L2_3 = SetInteriorProbeLength
      L3_3 = 0.0
      L2_3(L3_3)
    end
    L0_2(L1_2)
  end
end
markerThread = L6_1
L6_1 = RegisterNetEvent
L7_1 = "elevators:change"
function L8_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2, L6_2, L7_2
  L2_2 = L1_1
  L2_2 = L2_2[A0_2]
  if L2_2 then
    L2_2 = L1_1
    L2_2 = L2_2[A0_2]
    L3_2 = L2_2
    L2_2 = L2_2.isFloorValid
    L4_2 = A1_2
    L2_2 = L2_2(L3_2, L4_2)
    if L2_2 then
      L2_2 = L1_1
      L2_2 = L2_2[A0_2]
      L3_2 = L2_2
      L2_2 = L2_2.getMenuCoords
      L2_2 = L2_2(L3_2)
      L3_2 = L2_1
      L3_2 = L2_2 - L3_2
      L3_2 = #L3_2
      if L3_2 > 100 then
        L4_2 = L1_1
        L4_2 = L4_2[A0_2]
        L5_2 = L4_2
        L4_2 = L4_2.setFloor
        L6_2 = A1_2
        L7_2 = true
        L4_2(L5_2, L6_2, L7_2)
      else
        L4_2 = L1_1
        L4_2 = L4_2[A0_2]
        L5_2 = L4_2
        L4_2 = L4_2.setFloor
        L6_2 = A1_2
        L7_2 = false
        L4_2(L5_2, L6_2, L7_2)
      end
    end
  end
end
L6_1(L7_1, L8_1)
L6_1 = RegisterNetEvent
L7_1 = "elevators:sync"
function L8_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2
  L1_2 = pairs
  L2_2 = A0_2
  L1_2, L2_2, L3_2, L4_2 = L1_2(L2_2)
  for L5_2, L6_2 in L1_2, L2_2, L3_2, L4_2 do
    L7_2 = L1_1
    L7_2 = L7_2[L5_2]
    L8_2 = L7_2
    L7_2 = L7_2.isFloorValid
    L9_2 = L6_2
    L7_2 = L7_2(L8_2, L9_2)
    if L7_2 then
      L7_2 = L1_1
      L7_2 = L7_2[L5_2]
      L8_2 = L7_2
      L7_2 = L7_2.setFloor
      L9_2 = L6_2
      L10_2 = true
      L7_2(L8_2, L9_2, L10_2)
    end
  end
end
L6_1(L7_1, L8_1)
L6_1 = RegisterNUICallback
L7_1 = "close"
function L8_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2
  L2_2 = SetNuiFocus
  L3_2 = false
  L4_2 = false
  L2_2(L3_2, L4_2)
end
L6_1(L7_1, L8_1)
L6_1 = RegisterNUICallback
L7_1 = "elevatorFloor"
function L8_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2, L6_2
  L2_2 = A0_2.id
  if L2_2 then
    L2_2 = A0_2.select
    if L2_2 then
      L3_2 = A0_2.id
      L2_2 = L1_1
      L2_2 = L2_2[L3_2]
      if L2_2 then
        L4_2 = L2_2
        L3_2 = L2_2.isFloorValid
        L5_2 = A0_2.select
        L3_2 = L3_2(L4_2, L5_2)
        if L3_2 then
          L4_2 = L2_2
          L3_2 = L2_2.inMoviment
          L3_2 = L3_2(L4_2)
          if not L3_2 then
            L3_2 = TriggerServerEvent
            L4_2 = "elevators:update"
            L5_2 = A0_2.id
            L6_2 = A0_2.select
            L3_2(L4_2, L5_2, L6_2)
            L3_2 = SetNuiFocus
            L4_2 = false
            L5_2 = false
            L3_2(L4_2, L5_2)
          end
        end
      end
    end
  end
end
L6_1(L7_1, L8_1)
L6_1 = Citizen
L6_1 = L6_1.CreateThread
function L7_1()
  local L0_2, L1_2, L2_2, L3_2, L4_2
  L0_2 = SetDeepOceanScaler
  L1_2 = 0.0
  L0_2(L1_2)
  L0_2 = GetInteriorAtCoordsWithType
  L1_2 = 3925.5874
  L2_2 = 4880.2627
  L3_2 = 12.60829
  L4_2 = "int_maibnx_rest_asylum"
  L0_2 = L0_2(L1_2, L2_2, L3_2, L4_2)
  interiorID = L0_2
  L0_2 = IsValidInterior
  L1_2 = interiorID
  L0_2 = L0_2(L1_2)
  if L0_2 then
    L0_2 = secretRoom
    L0_2 = L0_2.DoorCanBeOpened
    if L0_2 then
      L0_2 = EnableInteriorProp
      L1_2 = interiorID
      L2_2 = "maibrnx_asylum_secretroom_porta_open"
      L0_2(L1_2, L2_2)
    else
      L0_2 = EnableInteriorProp
      L1_2 = interiorID
      L2_2 = "maibrnx_asylum_secretroom_porta_closed"
      L0_2(L1_2, L2_2)
    end
    L0_2 = secretRoom
    L0_2 = L0_2.Weed
    if L0_2 then
      L0_2 = EnableInteriorProp
      L1_2 = interiorID
      L2_2 = "maibrnx_asylum_secretroom_weed"
      L0_2(L1_2, L2_2)
    end
    L0_2 = secretRoom
    L0_2 = L0_2.Meth
    if L0_2 then
      L0_2 = EnableInteriorProp
      L1_2 = interiorID
      L2_2 = "maibrnx_asylum_secretroom_meth"
      L0_2(L1_2, L2_2)
    end
    L0_2 = secretRoom
    L0_2 = L0_2.Money
    if L0_2 then
      L0_2 = EnableInteriorProp
      L1_2 = interiorID
      L2_2 = "maibrnx_asylum_secretroom_money"
      L0_2(L1_2, L2_2)
    end
    L0_2 = secretRoom
    L0_2 = L0_2.Weapon
    if L0_2 then
      L0_2 = EnableInteriorProp
      L1_2 = interiorID
      L2_2 = "maibrnx_asylum_secretroom_weapon"
      L0_2(L1_2, L2_2)
    end
    L0_2 = secretRoom
    L0_2 = L0_2.Stock
    if L0_2 then
      L0_2 = EnableInteriorProp
      L1_2 = interiorID
      L2_2 = "maibrnx_asylum_secretroom_stock"
      L0_2(L1_2, L2_2)
    end
    L0_2 = RefreshInterior
    L1_2 = interiorID
    L0_2(L1_2)
  end
end
L6_1(L7_1)
