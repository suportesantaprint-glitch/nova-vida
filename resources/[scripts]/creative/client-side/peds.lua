-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Spawned = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- LIST
-----------------------------------------------------------------------------------------------------------------------------------------
local List = {
	{ -- Banned
		Distance = 100,
		Route = 9999998,
		Coords = vec4(-1674.58,-3174.77,13.99,331.66),
		Model = "a_m_m_bevhills_02",
		Collision = true
	},{ -- Essence
		Distance = 50,
		Coords = vec4(87.62,-1670.45,29.18,73.71),
		Model = "a_f_y_vinewood_01",
		Collision = true
	},{ -- Cow
		Distance = 50,
		Coords = vec4(957.99,-2207.26,30.6,266.46),
		Model = "a_c_cow",
		Collision = true
	},{ -- Cow
		Distance = 50,
		Coords = vec4(956.66,-2220.51,30.58,266.46),
		Model = "a_c_cow",
		Collision = true
	},{ -- Cow
		Distance = 50,
		Coords = vec4(955.6,-2233.52,30.58,266.46),
		Model = "a_c_cow",
		Collision = true
	},{ -- Cow
		Distance = 50,
		Coords = vec4(954.49,-2247.07,30.58,266.46),
		Model = "a_c_cow",
		Collision = true
	},{ -- Desmanche
		Distance = 100,
		Coords = vec4(778.49,-395.89,33.43,99.22),
		Model = "g_m_y_salvagoon_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Towed South
		Distance = 50,
		Coords = vec4(408.91,-1622.75,29.28,232.45),
		Model = "u_m_o_finguru_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Bus
		Distance = 50,
		Coords = vec4(453.47,-602.34,28.59,266.46),
		Model = "a_m_y_business_02",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Hotel
		Distance = 50,
		Coords = vec4(-772.76,312.81,85.7,181.42),
		Model = "s_m_y_doorman_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Grime
		Distance = 50,
		Coords = vec4(68.99,127.46,79.21,158.75),
		Model = "s_m_m_postal_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Megamall
		Distance = 50,
		Coords = vec4(2737.32,3462.1,55.69,340.16),
		Model = "ig_dale",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Clandestine
		Distance = 50,
		Coords = vec4(117.49,-1665.16,29.28,229.61),
		Model = "csb_paige",
		Anim = { "amb@lo_res_idles@","world_human_lean_male_foot_up_lo_res_base" }
	},{ -- Farmacia
		Distance = 50,
		Coords = vec4(72.41,-1572.71,29.6,42.52),
		Model = "s_m_m_doctor_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Eletronics
		Distance = 50,
		Coords = vec4(382.71,-825.52,29.32,272.13),
		Model = "ig_dale",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Taxi
		Distance = 50,
		Coords = vec4(901.97,-167.97,74.07,238.12),
		Model = "ig_dale",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Helicopters
		Distance = 100,
		Coords = vec4(-1896.42,-3032.01,13.93,243.78),
		Model = "g_m_y_korlieut_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Caminhoneiro
		Distance = 100,
		Coords = vec4(1239.87,-3257.2,7.09,274.97),
		Model = "s_m_m_trucker_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Cemitery
		Distance = 100,
		Coords = vec4(-1741.52,-219.85,56.14,255.12),
		Model = "g_m_m_armboss_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(24.51,-1346.75,29.49,272.13),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(2556.77,380.87,108.61,0.0),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(1164.81,-323.61,69.2,99.22),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(-706.16,-914.55,19.21,87.88),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(-47.35,-1758.59,29.42,45.36),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(372.7,326.89,103.56,255.12),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(-3242.7,1000.05,12.82,357.17),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(1728.08,6415.6,35.03,243.78),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(549.09,2670.89,42.16,93.55),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(1959.87,3740.44,32.33,300.48),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(2677.65,3279.66,55.23,331.66),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(1697.32,4923.46,42.06,323.15),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(-1819.52,793.48,138.08,130.4),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(1391.62,3605.95,34.98,198.43),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(-2966.41,391.52,15.05,82.21),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(-3039.42,584.42,7.9,14.18),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(1134.32,-983.09,46.4,277.8),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(1165.32,2710.79,38.15,175.75),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(-1486.72,-377.61,40.15,130.4),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Departament Store
		Distance = 15,
		Coords = vec4(-1221.48,-907.93,12.32,31.19),
		Model = "mp_m_shopkeep_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Ammu-Nation Store
		Distance = 15,
		Coords = vec4(1692.27,3760.91,34.69,226.78),
		Model = "ig_dale",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Ammu-Nation Store
		Distance = 15,
		Coords = vec4(253.8,-50.47,69.94,65.2),
		Model = "ig_dale",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Ammu-Nation Store
		Distance = 15,
		Coords = vec4(842.54,-1035.25,28.19,0.0),
		Model = "ig_dale",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Ammu-Nation Store
		Distance = 15,
		Coords = vec4(-331.67,6084.86,31.46,223.94),
		Model = "ig_dale",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Ammu-Nation Store
		Distance = 15,
		Coords = vec4(-662.37,-933.58,21.82,181.42),
		Model = "ig_dale",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Ammu-Nation Store
		Distance = 15,
		Coords = vec4(-1304.12,-394.56,36.7,73.71),
		Model = "ig_dale",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Ammu-Nation Store
		Distance = 15,
		Coords = vec4(-1118.98,2699.73,18.55,221.11),
		Model = "ig_dale",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Ammu-Nation Store
		Distance = 15,
		Coords = vec4(2567.98,292.62,108.73,0.0),
		Model = "ig_dale",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Ammu-Nation Store
		Distance = 15,
		Coords = vec4(-3173.51,1088.35,20.84,246.62),
		Model = "ig_dale",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Ammu-Nation Store
		Distance = 15,
		Coords = vec4(22.53,-1105.52,29.79,155.91),
		Model = "ig_dale",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Ammu-Nation Store
		Distance = 15,
		Coords = vec4(810.22,-2158.99,29.62,0.0),
		Model = "ig_dale",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Jewelry
		Distance = 15,
		Coords = vec4(-628.79,-238.7,38.05,311.82),
		Model = "cs_gurk",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Transporter
		Distance = 20,
		Coords = vec4(264.74,219.99,101.67,343.0),
		Model = "ig_casey",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Leiteiro
		Distance = 50,
		Coords = vec4(963.13,-2215.33,30.55,272.13),
		Model = "cs_manuel",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Lenhador
		Distance = 50,
		Coords = vec4(1961.61,5179.26,47.94,277.8),
		Model = "a_m_o_ktown_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Caçador
		Distance = 10,
		Coords = vec4(-679.14,5834.37,17.32,127.56),
		Model = "ig_hunter",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Caçador
		Distance = 50,
		Coords = vec4(-1593.08,5202.9,4.31,297.64),
		Model = "a_m_o_ktown_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Pescador
		Distance = 30,
		Coords = vec4(-1816.64,-1193.73,14.31,334.49),
		Model = "a_f_y_eastsa_03",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Dismantle
		Distance = 25,
		Coords = vec4(2340.7,3126.49,48.21,351.5),
		Model = "a_m_m_soucent_03",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Throwing
		Distance = 50,
		Coords = vec4(-537.13,-886.47,25.21,175.75),
		Model = "a_m_m_paparazzi_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Hospital
		Distance = 50,
		Coords = vec4(-348.85,-1933.27,30.33,65.2),
		Model = "s_m_m_doctor_01",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Drogas Chatuba
		Distance = 25,
		Coords = vec4(927.01,-1890.03,32.25,184.26),
		Model = "a_m_m_soucent_03",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Drogas Pica Pau
		Distance = 25,
		Coords = vec4(-2921.14,1364.38,76.41,289.14),
		Model = "a_m_m_soucent_03",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Drogas Favela03
		Distance = 25,
		Coords = vec4(-1750.2,-28.19,85.68,314.65),
		Model = "a_m_m_soucent_03",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Drogas Quitungo
		Distance = 25,
		Coords = vec4(1412.26,-770.36,67.23,59.53),
		Model = "a_m_m_soucent_03",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Drogas Borel
		Distance = 25,
		Coords = vec4(1411.72,-251.38,177.82,345.83),
		Model = "a_m_m_soucent_03",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Drogas Corte8
		Distance = 25,
		Coords = vec4(2499.7,2437.89,52.23,204.1),
		Model = "a_m_m_soucent_03",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Drogas Cesarão
		Distance = 25,
		Coords = vec4(1143.16,4009.23,45.34,198.43),
		Model = "a_m_m_soucent_03",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Drogas SãoConrado
		Distance = 25,
		Coords = vec4(-238.36,-1311.27,18.45,266.46),
		Model = "a_m_m_soucent_03",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Drogas GardeniaAzul
		Distance = 25,
		Coords = vec4(-1840.44,-1182.25,14.32,147.41),
		Model = "a_m_m_soucent_03",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Restaurante Pier
		Distance = 25,
		Coords = vec4(-4235.15,1752.2,28.37,345.83),
		Model = "a_m_m_soucent_03",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Restaurante Moo Moo Cafe
		Distance = 25,
		Coords = vec4(-590.09,-1056.65,22.33,0.0),
		Model = "a_m_m_soucent_03",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	},{ -- Armas
		Distance = 25,
		Coords = vec4(-2894.0,3775.59,12.69,240.95),
		Model = "a_m_m_soucent_03",
		Anim = { "anim@heists@heist_corona@single_team","single_team_loop_boss" }
	}
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADLIST
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		local Ped = PlayerPedId()
		local Coords = GetEntityCoords(Ped)

		for Number = 1,#List do
			local Distance = #(Coords - List[Number].Coords.xyz)
			if Distance <= List[Number].Distance and (not List[Number].Route or List[Number].Route == LocalPlayer.state.Route) then
				if not Spawned[Number] and LoadModel(List[Number].Model) then
					Spawned[Number] = CreatePed(26,List[Number].Model,List[Number].Coords.x,List[Number].Coords.y,List[Number].Coords.z - 1,List[Number].Coords.w,false,false)

					SetEntityInvincible(Spawned[Number],true)
					FreezeEntityPosition(Spawned[Number],true)
					DecorSetBool(Spawned[Number],"CREATIVE_PED",true)
					SetEntityAsMissionEntity(Spawned[Number],true,true)
					SetBlockingOfNonTemporaryEvents(Spawned[Number],true)

					if not List[Number].Collision then
						SetEntityNoCollisionEntity(Spawned[Number],Ped,false)
					end

					if List[Number].Anim and LoadAnim(List[Number].Anim[1]) then
						TaskPlayAnim(Spawned[Number],List[Number].Anim[1],List[Number].Anim[2],8.0,8.0,-1,1,0,0,0,0)
					end
				end
			else
				if Spawned[Number] then
					if DoesEntityExist(Spawned[Number]) then
						DeleteEntity(Spawned[Number])
					end

					Spawned[Number] = nil
				end
			end
		end

		Wait(1000)
	end
end)