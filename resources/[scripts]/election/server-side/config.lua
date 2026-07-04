-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
Permission = "Admin" -- Permissão para utilizar o comando.
CommandReset = "electionreset" -- Nome do comando para resetar a votação de um passaporte específico ou de todos os passaportes.
CommandStats = "electionstats" -- Nome do comando para visualizar as estatísticas da eleição.
-----------------------------------------------------------------------------------------------------------------------------------------
-- CANDIDATES
-----------------------------------------------------------------------------------------------------------------------------------------
Candidates = {
	[1] = {
		Name = "Prefeito",
		Candidates = {
			{ Image = "candidato1.jpg", Name = "Anderson Farias", Party = "PSD", Number = "55" },
			{ Image = "candidato1.jpg", Name = "Eduardo Cury", Party = "PSDB", Number = "22" },
			{ Image = "candidato1.jpg", Name = "Dr. Elton", Party = "UNIÃO", Number = "44" },
		}
	},
	[2] = {
		Name = "Vereador",
		Candidates = {
			{ Image = "candidato1.jpg", Name = "Amélia Naomi", Party = "PT", Number = "13500" },
			{ Image = "candidato1.jpg", Name = "Carlos Abranches", Party = "CIDADANIA", Number = "23510" },
			{ Image = "candidato1.jpg", Name = "Claudio Apolinário", Party = "PSD", Number = "55022" },
			{ Image = "candidato1.jpg", Name = "Fabião Zagueiro", Party = "PSD", Number = "55699" },
			{ Image = "candidato1.jpg", Name = "Farnando Petiti", Party = "PSDB", Number = "45605" },
			{ Image = "candidato1.jpg", Name = "Gilson Campos", Party = "PRD", Number = "10555" },
		}
	}
}
