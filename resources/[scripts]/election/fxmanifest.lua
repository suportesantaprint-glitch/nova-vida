fx_version "cerulean"
game "gta5"
lua54 "yes"

dependency "ox_lib"

ui_page "web-side/index.html"

client_scripts {
	"@vrp/lib/Utils.lua",
	"client-side/*"
}

server_scripts {
	"@vrp/lib/Utils.lua",
	"server-side/*"
}

shared_scripts {
	"@ox_lib/init.lua",
}

files {
	"web-side/**/*"
}
