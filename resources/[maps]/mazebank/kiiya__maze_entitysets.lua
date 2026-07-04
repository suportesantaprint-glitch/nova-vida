local L0_1, L1_1
L0_1 = Citizen
L0_1 = L0_1.CreateThread
function L1_1()
  local L0_2, L1_2, L2_2, L3_2
  L0_2 = RequestIpl
  L1_2 = "interior_mazebank_milo_"
  L0_2(L1_2)
  L0_2 = GetInteriorAtCoords
  L1_2 = -1300.286
  L2_2 = -830.2
  L3_2 = 19.8155
  L0_2 = L0_2(L1_2, L2_2, L3_2)
  interiorID = L0_2
  L0_2 = IsValidInterior
  L1_2 = interiorID
  L0_2 = L0_2(L1_2)
  if L0_2 then
    L0_2 = EnableInteriorProp
    L1_2 = interiorID
    L2_2 = "kiiya_entity_maze_trolly"
    L0_2(L1_2, L2_2)
    L0_2 = RefreshInterior
    L1_2 = interiorID
    L0_2(L1_2)
  end
end
L0_1(L1_1)
