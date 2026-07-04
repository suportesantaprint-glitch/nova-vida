-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
Config = {
	BankTaxWithdraw = 0.97,
	BankTaxTransfer = 0.97,
	MedicPlanDuration = 2592000,

	GoalsItems = { "dollar","scrapmetal","metalspring","wetdollar","dirtydollar","aluminum","copper","plastic","glass","rubber","meth","cocaine","joint","bullet_casings","upgradepistol1","lightgunparts","WEAPON_PISTOL_AMMO","weaponparts","pistolbody","mediumgunparts","smgbody","vest","WEAPON_SMG_AMMO","heavygunparts","steel_plate","riflebody","WEAPON_RIFLE_AMMO","gunpowder","screwssmall","plastictube","sheetmetal","roadsigns","tarp","gears","WEAPON_CARBINERIFLE","WEAPON_TACTICALRIFLE","WEAPON_BULLPUPRIFLE_MK2" },

	Paramedics = { -- Caso tenha outras permissões, adicione abaixo.
		Paramedico = true,
		Paramedico2 = true
	},

	Disabled = {
		Mansao01 = { "Tags","Bank","Goals","Perks" },
		Mansao02 = { "Tags","Bank","Goals","Perks" },
		Mansao03 = { "Tags","Bank","Goals","Perks" },
		Mansao04 = { "Tags","Bank","Goals","Perks" },
		Mansao05 = { "Tags","Bank","Goals","Perks" },
		Mansao06 = { "Tags","Bank","Goals","Perks" },
		Mansao07 = { "Tags","Bank","Goals","Perks" },
		Mansao08 = { "Tags","Bank","Goals","Perks" },
		Mansao09 = { "Tags","Bank","Goals","Perks" },
		Mansao10 = { "Tags","Bank","Goals","Perks" },
		Mansao11 = { "Tags","Bank","Goals","Perks" },
		Mansao12 = { "Tags","Bank","Goals","Perks" },
		Mansao13 = { "Tags","Bank","Goals","Perks" },

		Fazenda01 = { "Tags","Bank","Goals","Perks" },
		Fazenda02 = { "Tags","Bank","Goals","Perks" },
		Fazenda03 = { "Tags","Bank","Goals","Perks" },
		Fazenda04 = { "Tags","Bank","Goals","Perks" },
		Fazenda05 = { "Tags","Bank","Goals","Perks" },
		Fazenda06 = { "Tags","Bank","Goals","Perks" },
		Fazenda07 = { "Tags","Bank","Goals","Perks" },
		Fazenda08 = { "Tags","Bank","Goals","Perks" },
		Fazenda09 = { "Tags","Bank","Goals","Perks" },
		Fazenda10 = { "Tags","Bank","Goals","Perks" },
		Fazenda11 = { "Tags","Bank","Goals","Perks" },
		Fazenda12 = { "Tags","Bank","Goals","Perks" },
		Fazenda13 = { "Tags","Bank","Goals","Perks" },
		Fazenda14 = { "Tags","Bank","Goals","Perks" },
		Fazenda15 = { "Tags","Bank","Goals","Perks" },
		Fazenda16 = { "Tags","Bank","Goals","Perks" },
		Fazenda17 = { "Tags","Bank","Goals","Perks" },
		Fazenda18 = { "Tags","Bank","Goals","Perks" },
		Fazenda19 = { "Tags","Bank","Goals","Perks" },
		Fazenda20 = { "Tags","Bank","Goals","Perks" },
		Fazenda21 = { "Tags","Bank","Goals","Perks" },

		Porto = { "Tags","Bank","Goals","Perks" },
		Ilha = { "Tags","Bank","Goals","Perks" },
		Fabrica = { "Tags","Bank","Goals","Perks" }
	},

	Perks = {
		{
			Increase = 1,
			Type = "Members",
			Title = "Aumento de Limite",
			Image = "nui://painel/web-side/images/user.svg",
			Description = "Aumenta o limite máximo de membros do grupo.",
			Price = { 250000,275000,300000,325000,350000,375000,400000,425000,450000,475000,500000,525000,550000,575000,600000,625000,650000,675000,700000,725000,750000,775000,800000,825000,850000,875000,900000,925000,950000,975000,1000000,1025000,1050000,1075000,1100000,1125000,1150000,1175000,1200000,1225000,1250000,1275000,1300000,1325000,1350000,1375000,1400000,1425000,1450000,1475000 }
		},{
			Price = 10000000,
			Type = "Premium",
			Increase = 2592000,
			Title = "Benefícios de Grupo",
			Description = "Adquirir por <b>30 dias</b> as bonificações abaixo.<br>• Dobro de peso no compartimento dos membros.<br>• Limite máximo de <b>Sprays</b> no mapa de <s>3</s> para <s>5</s>.",
			Image = "nui://painel/web-side/images/user.svg"
		},{
			Increase = 1,
			Type = "Tags",
			Price = 500000,
			Title = "Aumento de Tags",
			Description = "Aumenta o limite máximo de tags do grupo.",
			Image = "nui://painel/web-side/images/user.svg"
		},{
			Increase = 1,
			Price = 500000,
			Type = "Announces",
			Title = "Aumento de Anúncios",
			Description = "Aumenta o limite máximo de anúncios do grupo.",
			Image = "nui://painel/web-side/images/user.svg"
		}
	}
}