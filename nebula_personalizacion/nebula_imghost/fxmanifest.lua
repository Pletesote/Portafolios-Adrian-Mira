fx_version 'cerulean'
game 'gta5'

author 'Nebula Dev'
description 'Microservicio NUI de subida de imágenes via Discord Webhook'
version '1.0.0'

-- Registramos los archivos de la web para que FiveM los cargue
files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

-- Definimos cuál es la página principal de la NUI
ui_page 'html/index.html'

client_script 'client.lua'