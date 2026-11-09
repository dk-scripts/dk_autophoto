fx_version "cerulean"
game "gta5"

lua54 "yes"

author "DK Development"
description "dk_autophoto - Tirador automático de fotos de roupas (open source)"
version "2.0.0"
repository "https://github.com/dk-scripts/dk_autophoto"

-- O recurso de screenshot (screenshot-basic) é detectado em runtime pelo nome, em
-- config.shared.screenshotResources. Por isso não há `dependency` aqui: a pasta
-- pode ter outro nome de servidor para servidor, e um nome fixo travaria o boot de
-- quem usa um diferente.

-- A ordem dos arquivos importa. Cada módulo se registra no namespace `Autophoto`
-- (modules/shared/loader.lua) e só enxerga os que vêm antes dele na lista.

shared_scripts {
    "modules/shared/loader.lua",
    "config/shared/config.lua",
    "modules/shared/constants.lua",
    "modules/shared/utils.lua",
    "modules/shared/cooldown.lua",
    "modules/shared/init.lua",
}

client_scripts {
    "config/client/config.lua",

    "locales/pt-br/game.lua",
    "locales/pt-br/ui.lua",
    "locales/pt-br/shared.lua",
    "locales/en/game.lua",
    "locales/en/ui.lua",
    "locales/en/shared.lua",
    "locales/client_loader.lua",

    "modules/client/framing.lua",
    "modules/client/enumerate.lua",
    "modules/client/capture.lua",
    "modules/client/nui.lua",
    "modules/client/queue.lua",
    "modules/client/init.lua",
    "src/client.lua",
}

server_scripts {
    "config/server/config.lua",

    -- O server só usa os textos de jogo.
    "locales/pt-br/game.lua",
    "locales/en/game.lua",
    "locales/server_loader.lua",

    "modules/server/storage.lua",
    "modules/server/manifest.lua",
    "modules/server/commands.lua",
    "modules/server/init.lua",
    "src/server.lua",
}

ui_page "web/index.html"

-- Só a interface vai para o client. As fotos geradas (output/) ficam de fora de
-- propósito: seriam milhares de arquivos baixados por todo jogador que conecta.
-- Sirva a pasta output/ por HTTP, como descreve o README.
files {
    "web/**/*",
}
