fx_version 'bodacious'
game 'gta5'
lua54 'yes'

shared_scripts {
	"@vrp/lib/Utils.lua",
	"@vrp/config/Global.lua",
	"config/**/*.lua"
}

client_scripts {
	"@vrp/config/Native.lua",
	"@PolyZone/client.lua",
	"client/**/*.lua"
}

server_scripts {
	"server/**/*.lua"
}
