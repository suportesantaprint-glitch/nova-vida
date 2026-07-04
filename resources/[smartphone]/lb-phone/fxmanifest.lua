fx_version "cerulean"
game "gta5"
lua54 "yes"

version "2.7.2"

shared_script {
    "config/*.lua",
    "shared/**/*.lua"
}

client_script {
    "@vrp/lib/Utils.lua",
    "lib/client/**.lua",
    "client/**.lua"
}

server_scripts {
    "@vrp/lib/Utils.lua",
    "@oxmysql/lib/MySQL.lua",
    "lib/server/**.lua",
    "server/**/*.lua",
}

files {
    "ui/dist/**/*",
    "ui/components.js",
    "config/**/*"
}

ui_page "ui/dist/index.html"

dependency "oxmysql"