-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYERCONNECTING
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("playerConnecting",function(_,_,deferrals)
	deferrals.defer()

	deferrals.handover({
		video = Video,
		socials = Socials,
		playlist = Playlist,
		theme = Theme,
		autoplay = Autoplay,
		shortcuts = Shortcuts
	})

	deferrals.done()
end)