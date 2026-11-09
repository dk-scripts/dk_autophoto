-- ============================================================================
-- Orquestrador do contexto client: registra NUI callbacks, eventos e cleanup
-- ============================================================================

local shared = Autophoto.use("shared")
local nui = Autophoto.use("client.nui")
local capture = Autophoto.use("client.capture")
local framing = Autophoto.use("client.framing")
local queue = Autophoto.use("client.queue")
local enumerate = Autophoto.use("client.enumerate")
local clientConfig = Autophoto.use("config.client")
local utils = shared.utils

local client = {}

-- ----------------------------------------------------------------------------
-- Preview / overlay: thread só ativa enquanto a UI está aberta (sob demanda)
-- ----------------------------------------------------------------------------
local overlayThread = false
local function ensureOverlayThread()
    if overlayThread then return end
    overlayThread = true
    CreateThread(function()
        while nui.isOpen() do
            framing.draw()
            Wait(0)
        end
        overlayThread = false
    end)
end

-- ----------------------------------------------------------------------------
-- Reposicionamento ao vivo: captura input por teclas enquanto ativo
-- ----------------------------------------------------------------------------
local repositioning = false

local function startRepositionLoop()
    if repositioning then return end
    repositioning = true
    local ctrl = clientConfig.controls
    local steps = clientConfig.camera.steps

    -- A UI fica visível, mas o INPUT vai para o jogo (senão o NUI captura as
    -- teclas e o loop abaixo nunca veria as setas/scroll).
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(true)

    local function finish(confirmed)
        repositioning = false
        SetNuiFocusKeepInput(false)
        SetNuiFocus(true, true) -- devolve o controle à UI
        nui.send("repositionEnd", { camera = capture.getCamState(), confirmed = confirmed })
    end

    CreateThread(function()
        while repositioning and nui.isOpen() do
            if IsControlPressed(0, ctrl.rotateLeft) then capture.adjust("sideAngle", -steps.angle) end
            if IsControlPressed(0, ctrl.rotateRight) then capture.adjust("sideAngle", steps.angle) end
            if IsControlPressed(0, ctrl.heightUp) then capture.adjust("height", steps.height) end
            if IsControlPressed(0, ctrl.heightDown) then capture.adjust("height", -steps.height) end
            if IsControlPressed(0, ctrl.zoomIn) then capture.adjust("distance", -steps.distance) end
            if IsControlPressed(0, ctrl.zoomOut) then capture.adjust("distance", steps.distance) end

            if IsControlJustPressed(0, ctrl.confirm) then
                finish(true)
            elseif IsControlJustPressed(0, ctrl.cancel) then
                finish(false)
            end

            Wait(0)
        end

        -- saiu por fechar a UI sem confirmar
        if not nui.isOpen() then
            SetNuiFocusKeepInput(false)
        end
        repositioning = false
    end)
end

-- ----------------------------------------------------------------------------
-- NUI callbacks (todos validam e sempre chamam cb)
-- ----------------------------------------------------------------------------
RegisterNUICallback("ready", function(_, cb)
    -- a UI sinaliza que carregou; já foi populada no open()
    nui.ok(cb)
end)

-- Contagens de drawables por categoria (a UI monta a grade de variações com isso).
-- Lido do ped já vestido; por isso é um callback (não vem no open, que não espera o ped).
RegisterNUICallback("getCounts", function(_, cb)
    local ped = capture.getPed()
    nui.ok(cb, {
        counts = enumerate.counts(ped),
        model = capture.getModel(),
        ext = shared.config.image.encoding or "webp",
    })
end)

-- imagem recortada devolvida pelo NUI (casada por ticket)
RegisterNUICallback("cropped", function(data, cb)
    if type(data) == "table" and type(data.ticket) == "number" then
        capture.resolveCrop(data.ticket, data.image)
    end
    nui.ok(cb)
end)

RegisterNUICallback("close", function(_, cb)
    repositioning = false
    -- reset (não só stop): zera a fila por completo antes de destruir o ped/câmera,
    -- garantindo que nenhuma captura em andamento recrie/use o ped após o cleanup.
    queue.reset()
    nui.close()
    nui.ok(cb)
end)

RegisterNUICallback("setGender", function(data, cb)
    if type(data) ~= "table" or (data.gender ~= "male" and data.gender ~= "female") then
        return nui.fail(cb, "bad_gender")
    end
    capture.setGender(data.gender)
    capture.startCamera()
    -- devolve o camState + a trava: a câmera realinha à parte travada do novo ped,
    -- então a UI atualiza os sliders e o estado do dropdown "prender câmera".
    nui.ok(cb, {
        gender = capture.getGender(),
        camera = capture.getCamState(),
        lock = capture.getLock(),
        counts = enumerate.counts(capture.getPed()),
        model = capture.getModel(),
    })
end)

RegisterNUICallback("setCamera", function(data, cb)
    if type(data) ~= "table" then return nui.fail(cb, "bad_data") end
    local cs = capture.setCamState(data)
    nui.ok(cb, { camera = cs })
end)

-- "Prender câmera": trava a câmera numa parte do corpo (ver lockTargets).
RegisterNUICallback("setLock", function(data, cb)
    if type(data) ~= "table" or type(data.value) ~= "string" then
        return nui.fail(cb, "bad_data")
    end
    local cs = capture.setLock(data.value)
    nui.ok(cb, { lock = capture.getLock(), camera = cs })
end)

-- Modo da câmera: "auto" (perfil por peça) ou "fixed" (uma câmera p/ tudo).
RegisterNUICallback("setCameraMode", function(data, cb)
    if type(data) ~= "table" or (data.mode ~= "auto" and data.mode ~= "fixed") then
        return nui.fail(cb, "bad_mode")
    end
    local mode = capture.setCameraMode(data.mode)
    nui.ok(cb, {
        mode = mode,
        camera = capture.getCamState(),
        lock = capture.getLock(),
        activeCategory = capture.getActiveCategory(),
    })
end)

-- Peça em foco (preview ao vivo no modo auto): muda a câmera para o perfil dela.
RegisterNUICallback("setActiveCategory", function(data, cb)
    if type(data) ~= "table" or type(data.category) ~= "string" then
        return nui.fail(cb, "bad_data")
    end
    local cs = capture.applyCategoryProfile(data.category)
    nui.ok(cb, {
        camera = cs,
        lock = capture.getLock(),
        category = capture.getActiveCategory(),
    })
end)

-- Salva o camState atual como override da categoria (sessão).
RegisterNUICallback("saveCategoryProfile", function(data, cb)
    if type(data) ~= "table" or type(data.category) ~= "string" then
        return nui.fail(cb, "bad_data")
    end
    local saved = capture.saveCategoryProfile(data.category)
    if saved then nui.ok(cb, { saved = true }) else nui.fail(cb, "save_failed") end
end)

RegisterNUICallback("setSquareSize", function(data, cb)
    if type(data) ~= "table" or type(data.value) ~= "number" then return nui.fail(cb, "bad_data") end
    clientConfig.framing.squareSize = utils.clamp(data.value, 0.2, 1.0)
    nui.ok(cb, { squareSize = clientConfig.framing.squareSize })
end)

RegisterNUICallback("resetCamera", function(_, cb)
    nui.ok(cb, { camera = capture.resetCamera() })
end)

RegisterNUICallback("setTextures", function(data, cb)
    if type(data) ~= "table" then return nui.fail(cb, "bad_data") end
    if data.value == "all" then
        shared.config.textures = "all"
    else
        shared.config.textures = "first"
    end
    nui.ok(cb, { textures = shared.config.textures })
end)

RegisterNUICallback("reposition", function(_, cb)
    startRepositionLoop()
    nui.ok(cb)
end)

RegisterNUICallback("start", function(data, cb)
    if type(data) ~= "table" or type(data.selected) ~= "table" then
        return nui.fail(cb, "bad_data")
    end
    local ok, err = queue.start(data.selected)
    if ok then nui.ok(cb) else nui.fail(cb, err) end
end)

RegisterNUICallback("pause", function(_, cb) nui.ok(cb, { paused = queue.pause() }) end)
RegisterNUICallback("resume", function(_, cb) nui.ok(cb, { resumed = queue.resume() }) end)
RegisterNUICallback("stop", function(_, cb) nui.ok(cb, { stopped = queue.stop() }) end)
RegisterNUICallback("retryFailed", function(_, cb)
    local ok, err = queue.retryFailed()
    if ok then nui.ok(cb) else nui.fail(cb, err) end
end)

-- ----------------------------------------------------------------------------
-- Eventos
-- ----------------------------------------------------------------------------
-- Resposta do server à solicitação de foto (casada por ticket).
RegisterNetEvent("dk_autophoto:client:shotResult", function(ticket, ok, data)
    capture.resolveShot(ticket, ok, data)
end)

--- Abre a UI e garante o overlay de preview. Ponto único de abertura.
function client.openUi()
    nui.open()
    ensureOverlayThread()
end

-- Server manda abrir a UI (após validar permissão/cooldown).
RegisterNetEvent("dk_autophoto:client:openUi", function()
    client.openUi()
end)

-- Aviso do server (sem permissão, cooldown) como notificação do jogo, que aparece
-- mesmo em servidores sem chat ou com chat customizado.
RegisterNetEvent("dk_autophoto:client:notify", function(message)
    if type(message) ~= "string" then return end

    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end)

-- ----------------------------------------------------------------------------
-- Cleanup
-- ----------------------------------------------------------------------------
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    repositioning = false
    queue.reset()
    capture.cleanup()
    SetNuiFocus(false, false)
end)

Autophoto.register("client.init", client)
return client
