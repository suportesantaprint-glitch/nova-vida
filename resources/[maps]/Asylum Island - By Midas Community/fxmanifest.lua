dependency "PL_PROTECT"
client_script "@PL_PROTECT/lib/plclient.lua"
server_script "@PL_PROTECT/lib/plserver.lua"

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

this_is_a_map "yes"

ui_page 'scripts/web/index.html'

client_scripts {
    'scripts/client.lua'
}

server_scripts {
    'scripts/server.lua'
}

shared_scripts {
    'config.lua'
}

data_file 'TIMECYCLEMOD_FILE' 'meta/asylum_timecycles.xml'
data_file 'AUDIO_GAMEDATA' 'meta/maibrnx_asylum_audio_game.dat'
data_file 'DLC_ITYP_REQUEST' 'stream/Interior/props/maibnx_rest_asylum_elevator.ytyp'

files {
    'meta/asylum_timecycles.xml',
	'meta/maibrnx_asylum_audio_game.dat151.rel',
    'scripts/web/**/*'
}

escrow_ignore {
    'config.lua'
}
dependency '/assetpacks'