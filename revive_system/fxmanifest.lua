fx_version 'cerulean'
game 'gta5'

author 'Basiik'
description 'Advanced Revive System'
version '1.0.0'

dependencies {
    'baseevents',
    'spawnmanager',
    'discord_perms'
}

-- Allow state bags set on Player() server-side to be read client-side
lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}
