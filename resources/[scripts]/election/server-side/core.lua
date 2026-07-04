-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRPC = Tunnel.getInterface("vRP")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- BUILDELECTIONSTATS
-----------------------------------------------------------------------------------------------------------------------------------------
local function BuildElectionStats(Election)
	local Stats = {}

	for Category,Data in pairs(Candidates) do
		Stats[Category] = { Name = Data.Name, Candidates = {} }
		for _,Candidate in ipairs(Data.Candidates) do
			Stats[Category].Candidates[Candidate.Number] = {
				Name = Candidate.Name,
				Party = Candidate.Party,
				Votes = 0
			}
		end
	end

	for _,Votes in pairs(Election) do
		if type(Votes) == "table" then
			for Category,Number in pairs(Votes) do
				local CategoryNumber = tonumber(Category)
				local CandidateNumber = tostring(Number)
				if CategoryNumber and Stats[CategoryNumber] and Stats[CategoryNumber].Candidates[CandidateNumber] then
					Stats[CategoryNumber].Candidates[CandidateNumber].Votes = Stats[CategoryNumber].Candidates[CandidateNumber].Votes + 1
				end
			end
		end
	end

	return Stats
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECK
-----------------------------------------------------------------------------------------------------------------------------------------
lib.callback.register("election:Check",function(source)
	local Passport = vRP.Passport(source)
	if not Passport then return false end

	local Election = vRP.GetSrvData("Election")
	local Votes = Election[tostring(Passport)] or {}

	local Total = 0
	for _ in pairs(Candidates) do Total = Total + 1 end
	local Voted = 0
	for _ in pairs(Votes) do Voted = Voted + 1 end

	if Voted >= Total then return false end

	return true
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
lib.callback.register("election:Config",function()
	return Candidates
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATE
-----------------------------------------------------------------------------------------------------------------------------------------
lib.callback.register("election:Update",function(source,Candidate,Vote)
	local Passport = vRP.Passport(source)
	if not Passport then return false end

	if not Candidates[Vote] or not Candidates[Vote].Candidates[Candidate] then
		return false
	end

	local Election = vRP.GetSrvData("Election")
	local PassportKey = tostring(Passport)
	local Votes = Election[PassportKey] or {}

	if Votes[tostring(Vote)] then return true end

	local CandidateData = Candidates[Vote].Candidates[Candidate]
	Votes[tostring(Vote)] = CandidateData.Number

	Election[PassportKey] = Votes
	vRP.SetSrvData("Election",Election,true)

	return true
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ELECTIONRESET
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand(CommandReset,function(source,Message)
	local Passport = vRP.Passport(source)
	if not Passport or not vRP.HasService(Passport,Permission) then
		return
	end

	local Argument = Message[1] and parseInt(Message[1]) or 0
	if Argument > 0 then
		local Election = vRP.GetSrvData("Election")
		Election[tostring(Argument)] = nil
		vRP.SetSrvData("Election",Election,true)

		TriggerClientEvent("Notify",source,"Sucesso",("Votação resetada para o passaporte <b>%s</b>."):format(Argument),"verde",5000)
		return
	end

	vRP.RemSrvData("Election")
	TriggerClientEvent("Notify",source,"Sucesso","Votação resetada para todos os jogadores.","verde",5000)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ELECTIONSTATS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand(CommandStats,function(source)
	local Passport = vRP.Passport(source)
	if not Passport then return end

	local Election = vRP.GetSrvData("Election")
	local Stats = BuildElectionStats(Election)
	local TotalVoters = 0
	local Lines = {}

	for _,Votes in pairs(Election) do
		if type(Votes) == "table" and next(Votes) then
			TotalVoters = TotalVoters + 1
		end
	end

	Lines[#Lines + 1] = "<b>Total de Eleitores:</b> "..TotalVoters
	Lines[#Lines + 1] = ""

	for Category = 1,#Candidates do
		if Stats[Category] then
			local BestVotes = -1
			local BestCandidates = {}
			Lines[#Lines + 1] = ("<b><warning>%s</warning></b>"):format(Stats[Category].Name)

			for _,Candidate in ipairs(Candidates[Category].Candidates) do
				local CandidateStats = Stats[Category].Candidates[Candidate.Number]
				local Votes = CandidateStats and CandidateStats.Votes or 0

				if Votes > BestVotes then
					BestVotes = Votes
					BestCandidates = { Candidate.Name }
				elseif Votes == BestVotes then
					BestCandidates[#BestCandidates + 1] = Candidate.Name
				end
			end

			for _,Candidate in ipairs(Candidates[Category].Candidates) do
				local CandidateStats = Stats[Category].Candidates[Candidate.Number]
				local Votes = CandidateStats and CandidateStats.Votes or 0
				local ColorTag = "offline"
				if Votes > 0 then
					ColorTag = "online"
				end

				Lines[#Lines + 1] = ("• <b>%s</b> (%s - %s): <%s>%s voto(s)</%s>"):format(Candidate.Name,Candidate.Party,Candidate.Number,ColorTag,Votes,ColorTag)
			end

			if BestVotes > 0 then
				Lines[#Lines + 1] = ("<b>Líder:</b> <verde>%s</verde> com <verde>%s voto(s)</verde>"):format(table.concat(BestCandidates,", "),BestVotes)
			else
				Lines[#Lines + 1] = "<b>Líder:</b> <amarelo>Nenhum voto registrado</amarelo>"
			end

			Lines[#Lines + 1] = " "
		end
	end

	TriggerClientEvent("Notify",source,"Estatísticas da Eleição",table.concat(Lines,"<br>"),"amarelo",20000)
end)
