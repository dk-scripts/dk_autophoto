-- ============================================================================
-- Config do CLIENT: ped, câmera, enquadramento, teclas, tema e hooks
-- ============================================================================

local config = {
    -- Ped dedicado que veste e posa cada peça para a foto.
    ped = {
        -- Modelos usados no botão Masculino/Feminino da UI. Para fotografar peças de um
        -- ped addon, troque o nome aqui e crie as entradas dele em `baseOutfit.byModel`.
        models = {
            male = "mp_m_freemode_01",
            female = "mp_f_freemode_01",
        },
        defaultGender = "male",

        -- Onde o ped é criado. Escolha um local isolado, sem players nem cenário, e com o
        -- chão carregado (um interior ou um mapa de fundo liso dá as melhores fotos).
        -- O padrão é um interior de garagem do mapa base.
        coords = vec4(221.21, -1004.65, -99.01, 272.13),

        -- Direção para onde o ped olha (a câmera fica na frente dele). 0 = norte.
        heading = 272.13,

        -- Roupa base: o estado "neutro" do ped, restaurado a cada slot depois de uma
        -- foto, para que a peça anterior não apareça no fundo da seguinte.
        -- Cada entrada é { drawable, texture } e a chave é o slot do component
        -- (modules/shared/constants.lua).
        --
        -- Existem dois presets, trocados automaticamente:
        --   preview -> ao abrir a UI. Peito/torso VISÍVEL, para você enquadrar a câmera.
        --   capture -> ao clicar em "Iniciar captura". Torso INVISÍVEL, para a roupa
        --              base não vazar nas fotos das outras categorias.
        -- Pausar, parar ou concluir a fila volta para o `preview`.
        --
        -- Os índices "vazio/mínimo" mudam de um modelo para outro (masculino, feminino,
        -- addons). Cada preset usa `byModel[<modelo atual>]` e, se o modelo não estiver
        -- listado, cai em `default`. Os valores abaixo servem aos peds padrão do GTA
        -- Online; com peds addon, adicione o seu modelo nos dois presets.
        --   enabled    -> liga/desliga a roupa base (nos dois presets).
        --   clearProps -> remove chapéu, óculos etc. ao aplicar qualquer preset.
        baseOutfit = {
            enabled = true,
            clearProps = true,

            preview = {
                default = {
                    components = {
                        [1] = { drawable = 0, texture = 0 }, -- mask
                        [3] = { drawable = 15, texture = 0 }, -- arms
                        [4] = { drawable = 14, texture = 0 }, -- pants
                        [5] = { drawable = 0, texture = 0 }, -- backpack
                        [6] = { drawable = 34, texture = 0 }, -- shoes
                        [7] = { drawable = 0, texture = 0 }, -- accessory
                        [8] = { drawable = 14, texture = 0 }, -- undershirt
                        [9] = { drawable = 0, texture = 0 }, -- vest
                        [10] = { drawable = 0, texture = 0 }, -- decals
                        [11] = { drawable = 0, texture = 0 }, -- torso / jacket
                    },
                },
                byModel = {
                    ["mp_m_freemode_01"] = {
                        components = {
                            [1] = { drawable = 0, texture = 0 }, -- mask
                            [3] = { drawable = 15, texture = 0 }, -- arms
                            [4] = { drawable = 14, texture = 0 }, -- pants
                            [5] = { drawable = 0, texture = 0 }, -- backpack
                            [6] = { drawable = 34, texture = 0 }, -- shoes
                            [7] = { drawable = 0, texture = 0 }, -- accessory
                            [8] = { drawable = 15, texture = 0 }, -- undershirt
                            [9] = { drawable = 0, texture = 0 }, -- vest
                            [10] = { drawable = 0, texture = 0 }, -- decals
                            [11] = { drawable = 15, texture = 0 }, -- torso / jacket
                        },
                    },
                    ["mp_f_freemode_01"] = {
                        components = {
                            [1] = { drawable = 0, texture = 0 }, -- mask
                            [3] = { drawable = 15, texture = 0 }, -- arms
                            [4] = { drawable = 15, texture = 0 }, -- pants
                            [5] = { drawable = 0, texture = 0 }, -- backpack
                            [6] = { drawable = 35, texture = 0 }, -- shoes
                            [7] = { drawable = 0, texture = 0 }, -- accessory
                            [8] = { drawable = 14, texture = 0 }, -- undershirt
                            [9] = { drawable = 0, texture = 0 }, -- vest
                            [10] = { drawable = 0, texture = 0 }, -- decals
                            [11] = { drawable = 15, texture = 0 }, -- torso / jacket
                        },
                    },
                },
            },

            capture = {
                default = {
                    components = {
                        [1] = { drawable = 0, texture = 0 }, -- mask
                        [3] = { drawable = 15, texture = 0 }, -- arms
                        [4] = { drawable = 14, texture = 0 }, -- pants
                        [5] = { drawable = 0, texture = 0 }, -- backpack
                        [6] = { drawable = 34, texture = 0 }, -- shoes
                        [7] = { drawable = 0, texture = 0 }, -- accessory
                        [8] = { drawable = 15, texture = 0 }, -- undershirt
                        [9] = { drawable = 0, texture = 0 }, -- vest
                        [10] = { drawable = 0, texture = 0 }, -- decals
                        [11] = { drawable = 15, texture = 0 }, -- torso / jacket
                    },
                },
                byModel = {
                    ["mp_m_freemode_01"] = {
                        components = {
                            [1] = { drawable = 0, texture = 0 }, -- mask
                            [3] = { drawable = 3, texture = 0 }, -- arms
                            [4] = { drawable = 11, texture = 0 }, -- pants
                            [5] = { drawable = 0, texture = 0 }, -- backpack
                            [6] = { drawable = 34, texture = 0 }, -- shoes
                            [7] = { drawable = 0, texture = 0 }, -- accessory
                            [8] = { drawable = 15, texture = 0 }, -- undershirt
                            [9] = { drawable = 0, texture = 0 }, -- vest
                            [10] = { drawable = 0, texture = 0 }, -- decals
                            [11] = { drawable = 15, texture = 0 }, -- torso / jacket
                        },
                    },
                    ["mp_f_freemode_01"] = {
                        components = {
                            [1] = { drawable = 0, texture = 0 }, -- mask
                            [3] = { drawable = 8, texture = 0 }, -- arms
                            [4] = { drawable = 13, texture = 0 }, -- pants
                            [5] = { drawable = 0, texture = 0 }, -- backpack
                            [6] = { drawable = 35, texture = 0 }, -- shoes
                            [7] = { drawable = 0, texture = 0 }, -- accessory
                            [8] = { drawable = 14, texture = 0 }, -- undershirt
                            [9] = { drawable = 0, texture = 0 }, -- vest
                            [10] = { drawable = 0, texture = 0 }, -- decals
                            [11] = { drawable = 82, texture = 0 }, -- torso / jacket
                        },
                    },
                },
            },
        },

        -- Pose do ped durante as fotos. Uma pose neutra, por padrão CONGELADA num frame
        -- (sem respirar nem balançar), deixa o catálogo consistente.
        --   enabled    -> false usa a postura padrão do ped.
        --   dict, name -> dicionário e nome da animação.
        --   blendIn    -> velocidade de entrada na animação (8.0 = instantânea).
        --   freeze     -> true trava num frame; false deixa a animação rodar.
        --   freezeTime -> frame travado, de 0.0 a 1.0.
        -- Outras poses para testar:
        --   { dict = "mp_character_creation@lowrider@male_a", name = "idle_a" }
        --   { dict = "anim@mp_player_intmenu@key_fob@", name = "fob_click" }
        pose = {
            enabled = true,
            dict = "anim@heists@heist_corona@team_idles@male_a",
            name = "idle",
            blendIn = 8.0,
            freeze = true,
            freezeTime = 0.0,
        },
    },

    -- Câmera de captura. Estes valores são o ponto de partida; você ajusta ao vivo na UI.
    -- Escreva os números sempre com casa decimal (32.0, não 32): os nativos de câmera
    -- esperam float e um inteiro distorce o enquadramento.
    camera = {
        fov = 32.0, -- campo de visão (menor = mais zoom)
        distance = 1.6, -- distância da câmera ao ped, em metros
        height = 0.65, -- altura do alvo a partir dos pés, em metros
        pitch = 0.0, -- inclinação vertical, em graus
        sideAngle = 0.0, -- giro ao redor do ped, em graus (0 = de frente)

        -- Deslocamentos finos do alvo, somados ao ponto mirado:
        --   heightOffset -> sobe/desce o alvo, em metros. Só funciona com a câmera presa
        --                   a uma parte do corpo (lock diferente de "free"). Útil porque
        --                   o ponto do corpo nem sempre coincide com a peça: o da cabeça
        --                   fica perto do queixo, abaixo de chapéus e óculos.
        --   sideOffset   -> desloca câmera e alvo para o lado, em metros. Útil quando a
        --                   parte do corpo não fica no centro do ped (mão, quadril).
        heightOffset = 0.0,
        sideOffset = 0.0,

        -- Limites do ajuste ao vivo, para não perder o ped de vista. A altura aceita
        -- valores negativos para chegar até os pés (calçados e calças).
        limits = {
            fov = { min = 12.0, max = 70.0 },
            distance = { min = 0.6, max = 4.0 },
            height = { min = -0.6, max = 1.2 },
            pitch = { min = -45.0, max = 45.0 },
            heightOffset = { min = -0.5, max = 0.5 },
            sideOffset = { min = -0.5, max = 0.5 },
        },

        -- Tamanho de cada passo ao ajustar com as teclas.
        steps = { fov = 1.0, distance = 0.05, height = 0.02, pitch = 1.0, angle = 3.0, offset = 0.02 },

        -- "Prender câmera": a câmera mira continuamente uma parte do corpo e acompanha
        -- o ped ao trocar de modelo ou de roupa. Com a câmera presa, o slider de altura
        -- fica oculto; "free" devolve a altura manual.
        -- `defaultLock` é a trava inicial. `bone` é o id do osso (decimal, como o
        -- GetPedBoneIndex espera); se o modelo não tiver o osso, a câmera usa o alvo
        -- manual. O nome mostrado na UI vem do locale (ui.lockChest, ui.lockFeet...).
        -- `centerXY = true` usa o centro do ped no plano e só a altura do osso, para
        -- ossos fora do eixo central (pé esquerdo) não jogarem o alvo para o canto.
        defaultLock = "head",
        lockTargets = {
            { key = "free", bone = nil },
            { key = "head", bone = 31086 }, -- SKEL_Head
            { key = "neck", bone = 39317 }, -- SKEL_Neck_1
            { key = "chest", bone = 24818 }, -- SKEL_Spine3
            { key = "waist", bone = 11816 }, -- SKEL_Pelvis
            { key = "legs", bone = 58271 }, -- SKEL_L_Thigh
            { key = "feet", bone = 14201, centerXY = true }, -- SKEL_L_Foot
            { key = "full", bone = nil, fullBody = true }, -- ponto médio entre pés e cabeça
        },

        -- Modo inicial da câmera, alternável na UI (aba Câmera):
        --   "auto"  -> cada categoria usa o seu perfil de `autoProfiles`
        --   "fixed" -> uma única câmera (os valores de `camera` acima) para todas
        defaultMode = "auto",

        -- Tempo extra (ms), somado ao `settleMs`, para a câmera assentar depois de
        -- trocar de perfil no modo auto e antes do screenshot.
        cameraSettleMs = 80,

        -- Perfis do modo auto, um por categoria (nomes em modules/shared/constants.lua).
        -- Cada perfil só precisa dos campos que MUDAM em relação a `camera` acima; o
        -- resto é herdado. `lock` usa as keys de `lockTargets`. `default` vale para
        -- categorias sem perfil próprio.
        --
        -- `turnPedAround = true` gira o PED 180° em vez da câmera, para fotografar as
        -- costas. A câmera fica sempre no mesmo lugar, longe de paredes que ocluiriam a
        -- imagem se ela passasse para trás do ped.
        --
        -- Os valores foram calibrados nos peds padrão do GTA Online; com outro mapa ou
        -- ped, ajuste pela UI (aba Câmera) e copie os números para cá.
        autoProfiles = {
            default = { lock = "full" },
            tshirt = { lock = "chest", fov = 50.0, distance = 1.50, sideAngle = 30.0 },
            torso = { lock = "free", fov = 50.0, distance = 1.50, sideAngle = 30.0, height = 0.20 },
            vest = { lock = "chest", fov = 50.0, distance = 1.50, sideAngle = 30.0 },
            arms = { lock = "chest", fov = 50.0, distance = 1.60, sideAngle = 30.0, heightOffset = -0.10 },
            decals = { lock = "chest", fov = 50.0, distance = 1.50, sideAngle = 30.0 },
            accessory = { lock = "chest", fov = 50.0, distance = 1.50, sideAngle = 30.0 },
            pants = { lock = "free", fov = 50.0, distance = 2.15, sideAngle = 20.0, pitch = 0.0, height = -0.48 },
            shoes = { lock = "feet", fov = 40.0, distance = 1.40, sideAngle = 70.0 },
            backpack = { lock = "chest", fov = 50.0, distance = 1.50, sideAngle = 0.0, turnPedAround = true },
            mask = { lock = "head", fov = 30.0, distance = 1.20, sideAngle = 30.0, heightOffset = 0.06 },
            hat = { lock = "head", fov = 28.0, distance = 1.10, sideAngle = 30.0, heightOffset = 0.10 },
            glass = { lock = "head", fov = 24.0, distance = 0.85, sideAngle = 15.0, heightOffset = 0.05 },
            ear = { lock = "head", fov = 18.0, distance = 1.3, sideAngle = 15.0, heightOffset = 0.02 },
            watch = { lock = "free", fov = 47.0, distance = 1.0, sideAngle = 63.0, height = -0.04 },
            bracelet = { lock = "free", fov = 47.0, distance = 1.0, sideAngle = 300.0, height = -0.04 },
        },
    },

    -- Quadro da foto. A foto final é recortada neste quadrado (o lado é `image.size`,
    -- em config/shared).
    --   squareSize  -> lado do quadrado como fração da MENOR dimensão da tela (0 a 1);
    --                  0.62 = 62% da altura. Ajustável na UI ("Tamanho do quadro").
    --   showOverlay -> desenha o quadrado-guia enquanto a UI está aberta.
    --   dimOutside  -> escurece a área fora do quadrado.
    --   dimAlpha    -> opacidade desse escurecimento, de 0 a 255.
    framing = {
        squareSize = 0.62,
        showOverlay = true,
        dimOutside = true,
        dimAlpha = 180,
    },

    -- Espera (ms) depois de vestir a peça e antes do screenshot, para as texturas
    -- carregarem. Aumente em máquinas lentas se as fotos saírem com a peça incompleta.
    settleMs = 150,

    -- Espera (ms) entre uma foto e a próxima, para não sobrecarregar o screenshot-basic.
    betweenShotsMs = 60,

    -- Teclas do modo "Reposicionar câmera" (control ids do FiveM).
    -- Lista: https://docs.fivem.net/docs/game-references/controls/
    controls = {
        rotateLeft = 174, -- seta esquerda
        rotateRight = 175, -- seta direita
        heightUp = 172, -- seta cima
        heightDown = 173, -- seta baixo
        zoomIn = 241, -- scroll para cima
        zoomOut = 242, -- scroll para baixo
        confirm = 191, -- enter
        cancel = 194, -- backspace
    },

    -- Cores da UI. Viram variáveis CSS (--dk-primary etc.) quando a UI abre.
    ui = {
        theme = {
            primary = "#7c5cff",
            background = "#0b0b0f",
            card = "#15151c",
            text = "#f5f5f7",
            muted = "#9a9aa8",
            success = "#3ecf8e",
            danger = "#ff5c7c",
            radius = "14px",
        },
    },

    -- Hooks do client. Rodam sob pcall: um erro seu nunca derruba o recurso.
    hooks = {
        -- Retorne false para pular esta foto.
        onBeforeShot = function(item) return true end,

        -- `path` é o caminho da foto salva, relativo à pasta de saída.
        onShot = function(item, path) end,
        onProgress = function(progress) end,

        -- stats = { total, saved, failed }
        onComplete = function(stats) end,
        onError = function(item, err) end,
    },
}

Autophoto.register("config.client", config)
return config
