-- ============================================================================
-- Queue: máquina de estados da captura (start/pause/resume/stop/retry)
--
-- Roda numa thread sob demanda (criada no start, encerrada no stop/done). Não há
-- loop global. O progresso é enviado à NUI só quando muda.
-- ============================================================================

local shared = Autophoto.use("shared")
local capture = Autophoto.use("client.capture")
local enumerate = Autophoto.use("client.enumerate")
local nui = Autophoto.use("client.nui")
local clientConfig = Autophoto.use("config.client")
local utils = shared.utils
local STATUS = shared.constants.STATUS
local debugPrint = utils.debugPrint

local queue = {}

local state = {
    status = STATUS.IDLE,
    items = {},
    index = 0,
    saved = 0,
    failed = {}, -- lista de itens que falharam
    doneKeys = {}, -- set de chaves já salvas (evita refazer ao retomar)
    startedAt = nil,
    threadRunning = false,
}

-- ----------------------------------------------------------------------------
-- Hooks do usuário (sob pcall)
-- ----------------------------------------------------------------------------
local function runHook(name, ...)
    local fn = clientConfig.hooks and clientConfig.hooks[name]
    return utils.safeCall("hook." .. name, fn, nil, ...)
end

-- ----------------------------------------------------------------------------
-- Progresso → NUI (só quando muda)
-- ----------------------------------------------------------------------------
local lastSent = nil

local function progressSnapshot()
    local total = #state.items
    local current = state.items[state.index]
    return {
        status = state.status,
        index = state.index,
        total = total,
        saved = state.saved,
        failed = #state.failed,
        remaining = math.max(0, total - state.index),
        current = current and {
            category = current.category,
            drawable = current.drawable,
            texture = current.texture,
        } or nil,
        eta = queue.estimateEta(),
    }
end

local function pushProgress(force)
    local snap = progressSnapshot()
    local sig = ("%s|%d|%d|%d|%d"):format(snap.status, snap.index, snap.total, snap.saved, snap.failed)
    if force or sig ~= lastSent then
        lastSent = sig
        nui.send("progress", snap)
        runHook("onProgress", snap)
    end
end

--- Estimativa de tempo restante (ms) com base no ritmo médio até agora.
function queue.estimateEta()
    if not state.startedAt or state.index <= 0 then return nil end
    local elapsed = GetGameTimer() - state.startedAt
    local perItem = elapsed / state.index
    local remaining = math.max(0, #state.items - state.index)
    return math.floor(perItem * remaining)
end

-- ----------------------------------------------------------------------------
-- Thread de captura
-- ----------------------------------------------------------------------------
local function captureOne(item)
    -- aborta se a fila foi parada no meio do caminho (ex.: UI fechada): assim a
    -- thread não recria/usa o ped depois do cleanup do close (getPed é idempotente
    -- e recriaria um ped órfão).
    if state.status ~= STATUS.RUNNING then return false end

    -- hook pode cancelar esta foto
    if runHook("onBeforeShot", item) == false then
        return true  -- "ok" (pulada por decisão do usuário), não conta como falha
    end

    -- modo auto: a câmera vai para o perfil desta categoria antes de fotografar
    if capture.getCameraMode() == "auto" then
        capture.applyCategoryProfile(item.category)
        Wait(clientConfig.camera.cameraSettleMs or 80)
    end

    capture.dress(item)
    Wait(clientConfig.settleMs)

    local ok, data = capture.shoot(item)

    if ok then
        state.saved = state.saved + 1
        state.doneKeys[utils.itemKey(item)] = true
        runHook("onShot", item, data)
    else
        state.failed[#state.failed + 1] = item
        runHook("onError", item, data)
        debugPrint("falha ao fotografar", utils.itemKey(item), "->", tostring(data))
    end

    capture.resetSlot(item)
    Wait(clientConfig.betweenShotsMs)
    return ok
end

local function startThread()
    if state.threadRunning then return end
    state.threadRunning = true

    CreateThread(function()
        -- Roda enquanto não foi parado (IDLE) nem concluído (DONE). PAUSED dorme.
        while state.status == STATUS.RUNNING or state.status == STATUS.PAUSED do
            if state.status == STATUS.PAUSED then
                pushProgress(false)
                Wait(200)
            else
                local nextIndex = state.index + 1
                if nextIndex > #state.items then
                    state.status = STATUS.DONE
                    break
                end

                state.index = nextIndex
                local item = state.items[state.index]

                -- pula o que já foi salvo (retomada sem refazer)
                if not state.doneKeys[utils.itemKey(item)] then
                    pushProgress(false)
                    captureOne(item)
                end
                pushProgress(false)
            end
        end

        state.threadRunning = false

        if state.status == STATUS.DONE then
            -- captura terminou: volta o torso a ficar visível (preset "preview").
            capture.applyOutfitPreset("preview")
            pushProgress(true)
            local stats = { total = #state.items, saved = state.saved, failed = #state.failed }
            runHook("onComplete", stats)
            TriggerServerEvent("dk_autophoto:server:captureComplete", stats)
        end
    end)
end

-- ----------------------------------------------------------------------------
-- API pública (chamada pelos callbacks NUI em init.lua)
-- ----------------------------------------------------------------------------

--- Inicia a captura das categorias selecionadas.
---@param selected table<string, true|integer[]>  -- categoria -> true (todas) | lista de drawables
function queue.start(selected)
    if state.status == STATUS.RUNNING then return false, "already_running" end

    local ped = capture.getPed()
    state.items = enumerate.build(ped, selected or {})
    if #state.items == 0 then return false, "empty" end

    state.index = 0
    state.saved = 0
    state.failed = {}
    state.doneKeys = {}
    state.startedAt = GetGameTimer()
    state.status = STATUS.RUNNING

    -- preset "capture": torso/peito invisível, para não vazar roupa no fundo
    -- das fotos (o preview de ajuste usa o preset "preview", torso visível).
    capture.applyOutfitPreset("capture")

    TriggerServerEvent("dk_autophoto:server:sessionStart")
    pushProgress(true)
    startThread()
    return true
end

function queue.pause()
    -- A thread continua viva e detecta PAUSED (dorme sem capturar).
    if state.status == STATUS.RUNNING then
        state.status = STATUS.PAUSED
        -- volta o torso a ficar visível enquanto pausado, para reajustar a câmera.
        capture.applyOutfitPreset("preview")
        pushProgress(true)
        return true
    end
    return false
end

function queue.resume()
    if state.status == STATUS.PAUSED then
        state.status = STATUS.RUNNING
        capture.applyOutfitPreset("capture")
        startThread()  -- no-op se a thread ainda viva; recria se tinha encerrado
        pushProgress(true)
        return true
    end
    return false
end

function queue.stop()
    state.status = STATUS.IDLE
    state.threadRunning = false
    capture.applyOutfitPreset("preview")
    pushProgress(true)
    return true
end

--- Reenfileira apenas os itens que falharam e recomeça.
function queue.retryFailed()
    if #state.failed == 0 then return false, "no_failures" end
    if state.status == STATUS.RUNNING then return false, "already_running" end

    state.items = state.failed
    state.failed = {}
    state.index = 0
    state.saved = 0
    state.doneKeys = {}
    state.startedAt = GetGameTimer()
    state.status = STATUS.RUNNING

    capture.applyOutfitPreset("capture")
    pushProgress(true)
    startThread()
    return true
end

function queue.reset()
    state.status = STATUS.IDLE
    state.items = {}
    state.index = 0
    state.saved = 0
    state.failed = {}
    state.doneKeys = {}
    state.threadRunning = false
end

Autophoto.register("client.queue", queue)
return queue
