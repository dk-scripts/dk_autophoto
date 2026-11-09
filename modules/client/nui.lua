-- ============================================================================
-- NUI bridge: foco, mensagens action/data e registro dos callbacks
-- ============================================================================

local shared = Autophoto.use("shared")
local clientConfig = Autophoto.use("config.client")
local Locale = Autophoto.use("Locale")
local capture = Autophoto.use("client.capture")
local framing = Autophoto.use("client.framing")

local nui = {}

local isOpen = false

--- Envia mensagem padronizada { action, data } à NUI.
function nui.send(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

function nui.isOpen() return isOpen end

--- Abre a UI: foco, ped+câmera ligados, manda config inicial.
function nui.open()
    if isOpen then return end
    isOpen = true

    -- preset "preview": torso/peito visível, para o operador enquadrar a câmera
    -- antes de iniciar (queue.start troca para "capture" na hora de fotografar).
    capture.applyOutfitPreset("preview")
    capture.startCamera()

    SetNuiFocus(true, true)
    nui.send("open", {
        locale = Locale.uiPack(),
        theme = clientConfig.ui.theme,
        categories = shared.constants.CATEGORIES,
        order = shared.constants.ORDER,
        defaults = shared.config.categories,
        textures = shared.config.textures,
        gender = capture.getGender(),
        camera = capture.getCamState(),
        squareSize = clientConfig.framing.squareSize,
        -- "prender câmera": opções do dropdown (só as keys, em ordem) + trava atual.
        lockTargets = capture.getLockKeys(),
        lock = capture.getLock(),
        -- modo da câmera (auto = perfil por peça; fixed = câmera única) + peça em foco.
        cameraMode = capture.getCameraMode(),
        activeCategory = capture.getActiveCategory(),
    })
end

--- Fecha a UI: tira foco, desliga a câmera de captura e exclui o ped.
--- capture.cleanup() faz stopCamera() (devolve a render ao jogador) + destroyPed()
--- + limpa tickets. Sem isso, fechar (botão/ESC) deixava a câmera no ped e o ped
--- spawnado. É idempotente, então é seguro chamar em qualquer caminho de close.
function nui.close()
    if not isOpen then return end
    isOpen = false

    SetNuiFocus(false, false)
    framing.setOverlay(false)
    capture.cleanup()
    nui.send("close", {})
end

-- ----------------------------------------------------------------------------
-- Callbacks NUI — todos validam e SEMPRE chamam cb.
-- ----------------------------------------------------------------------------
-- O registro real dos callbacks fica em init.lua (precisa do queue), mas
-- expomos helpers de resposta aqui.

--- Resposta padrão de sucesso/erro.
function nui.ok(cb, data) cb({ success = true, data = data or {} }) end
function nui.fail(cb, msg)  cb({ success = false, error = msg or "error" }) end

Autophoto.register("client.nui", nui)
return nui
