-- ============================================================================
-- Config compartilhada (lida pelo client e pelo server)
-- ============================================================================

local config = {
    -- Idioma da UI e das mensagens do jogo: "pt-br" ou "en".
    locale = "pt-br",

    debug = {
        enabled = false,
    },

    -- Nome do recurso de screenshot. O nome da pasta varia de servidor para servidor,
    -- então o script usa o primeiro da lista que estiver iniciado. Se o seu tiver outro
    -- nome, acrescente aqui.
    screenshotResources = { "screenshot-basic", "screenshot" },

    -- Formato das fotos. A captura acontece no client, por isso estes valores ficam
    -- aqui e não só no server.
    --   encoding -> "webp", "png" ou "jpg"
    --   quality  -> de 0.0 a 1.0
    --   size     -> lado, em pixels, do arquivo final. A tela inteira é recortada num
    --               quadrado size x size, seguindo o quadro-guia da UI.
    image = {
        encoding = "webp",
        quality = 0.95,
        size = 512,
    },

    -- Quais texturas (cores) de cada peça fotografar. A UI também alterna entre
    -- "first" e "all" por sessão.
    --   "first"     -> só a textura 0 (uma foto por peça)
    --   "all"       -> todas as texturas da peça (muito mais fotos e tempo)
    --   { max = N } -> da textura 0 até N-1, limitado ao que existir
    textures = "first",

    -- Categorias marcadas ao abrir a UI. É só o ponto de partida: você marca e
    -- desmarca na UI a cada sessão. Os slots de cada uma estão em
    -- modules/shared/constants.lua.
    categories = {
        -- components
        mask = true,
        arms = true,
        tshirt = true, -- camiseta (undershirt)
        vest = true, -- colete
        torso = true, -- jaqueta / torso principal
        decals = true,
        accessory = true, -- correntes e colares
        backpack = true,
        pants = true,
        shoes = true,
        -- props
        hat = true,
        glass = true,
        ear = true,
        watch = true,
        bracelet = true,
    },
}

Autophoto.register("config.shared", config)
return config
