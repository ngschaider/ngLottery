fx_version 'cerulean'

games { 
	'gta5' 
}

name 'ngLottery'
author 'Niklas Gschaider <niklas.gschaider@gschaider-systems.at>'
description 'Adds markers to start player-managed lotteries'
version 'v1.0.0'

dependencies {
	"es_extended",
}

client_scripts {
	'@NativeUI/NativeUI.lua',
	'@es_extended/locale.lua',
	"locales/de.lua",
	"config.lua",
	"shared.lua",
	"client.lua",
}

server_scripts {
	'@mysql-async/lib/MySQL.lua',
	'@es_extended/locale.lua',
	"locales/de.lua",
	"config.lua",
	"shared.lua",
	"server.lua",
}