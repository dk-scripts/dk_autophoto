-- ============================================================================
-- Config do SERVER: onde salvar as fotos, permissão, comando e logs
-- ============================================================================

local config = {
    output = {
        -- Pasta onde as fotos e o index.json são salvos, dentro do recurso. Ela já vem
        -- no download (output/.gitkeep); você não precisa criá-la.
        dir = "output",

        -- Caminho de cada foto dentro de `dir`. Pode ter subpastas, que são criadas
        -- sozinhas. Os padrões abaixo são substituídos:
        --   {sex}       -> modelo do ped (mp_m_freemode_01)
        --   {gender}    -> male ou female
        --   {part}      -> categoria da peça (torso, pants, hat...)
        --   {slot}      -> slot do component/prop no jogo
        --   {variation} -> índice da peça (drawable)
        --   {color}     -> índice da textura
        --   {ext}       -> extensão do arquivo (webp, png ou jpg)
        --
        -- O padrão abaixo gera mp_m_freemode_01/torso/4_0.webp, a mesma estrutura que o
        -- dk_skinshop espera. Outros exemplos:
        --   "{gender}/{part}/{variation}.{ext}" -> male/torso/4.webp
        --   "{part}_{variation}_{color}.{ext}"  -> torso_4_0.webp (sem subpastas)
        --
        -- Se a sua loja de roupas espera outra estrutura, ajuste aqui. Troque o caminho
        -- antes de fotografar: fotos já salvas não são movidas.
        path = "{sex}/{part}/{variation}_{color}.{ext}",
    },

    -- Quem pode abrir a UI e salvar fotos. Vem DESLIGADO para o recurso funcionar logo
    -- depois de instalado, e o console do servidor avisa isso a cada inicialização.
    --
    -- Atenção: salvar foto grava arquivos no servidor. Com `enabled = false`, QUALQUER
    -- jogador conectado pode abrir a UI e gravar arquivos. Em servidor aberto, ligue e
    -- libere só quem precisa, no server.cfg:
    --   add_ace identifier.license:XXXX command.dk_autophoto allow
    --   add_ace group.fotografos command.dk_autophoto allow
    -- Quem tem o ACE `command` liberado (o grupo admin do txAdmin, por exemplo) já passa.
    permission = {
        enabled = false,
        ace = "command.dk_autophoto",
    },

    -- Comando que abre a UI (no jogo: /autophoto).
    command = {
        name = "autophoto",
    },

    -- Tempo mínimo (ms) entre duas aberturas da UI pelo mesmo jogador.
    cooldownMs = 1500,

    -- Logs no console do server e, opcionalmente, num webhook do Discord.
    logs = {
        enabled = false,
        webhook = "", -- URL do webhook do Discord; vazio = só console
        categories = {
            session = true, -- início e fim de cada sessão de captura
            errors = true, -- fotos que falharam ao salvar
        },
    },

    -- Hooks do server. Rodam sob pcall: um erro seu nunca derruba o recurso.
    hooks = {
        onSessionStart = function(playerId) end,

        -- stats = { total, saved, failed }
        onComplete = function(playerId, stats) end,
        onError = function(playerId, err) end,
    },
}

Autophoto.register("config.server", config)
return config
