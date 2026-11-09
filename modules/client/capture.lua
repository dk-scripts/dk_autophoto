-- ============================================================================
-- Capture: ped dedicado + câmera + vestir a peça + fotografar
--
-- O ped é criado num local isolado, vestido com cada peça e fotografado. A foto é
-- tirada aqui no client: o recurso de screenshot devolve a tela inteira, a NUI
-- recorta o quadrado e o resultado segue para o server gravar no disco. Cada
-- etapa espera a resposta casando por ticket.
-- ============================================================================

local shared = Autophoto.use("shared")
local clientConfig = Autophoto.use("config.client")
local framing = Autophoto.use("client.framing")
local clamp = shared.utils.clamp
local debugPrint = shared.utils.debugPrint

local capture = {}

-- ----------------------------------------------------------------------------
-- Estado da câmera (ajustável ao vivo). Inicia da config.
-- ----------------------------------------------------------------------------
local cam = nil
local capturePed = nil
local camState = nil
local gender = clientConfig.ped.defaultGender

-- Preset de roupa base ativo no ped: "preview" (torso visível, ajuste de câmera)
-- ou "capture" (torso invisível, durante a fila de fotos). Ver baseOutfit na
-- config.client e capture.applyOutfitPreset.
local outfitPreset = "preview"

-- Modo da câmera: "auto" (perfil por categoria) ou "fixed" (camera.* base).
local cameraMode = clientConfig.camera.defaultMode == "fixed" and "fixed" or "auto"
-- Overrides de perfil salvos pelo operador NA SESSÃO (categoria -> perfil parcial).
-- Sobrepõem os autoProfiles do config; não persistem em arquivo.
local autoOverrides = {}
-- Categoria cujo perfil a câmera está exibindo agora (preview/captura).
local activeCategory = nil

-- Respostas pendentes, por ticket: gravação no server e recorte na NUI.
local pendingShots = {}
local pendingCrops = {}
local ticketSeq = 0

-- Usa SendNUIMessage direto, e não o módulo client.nui, porque ele é carregado
-- depois deste na ordem do fxmanifest.
local function nuiSend(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

local function freshCamState()
    local c = clientConfig.camera
    return {
        fov = c.fov, distance = c.distance, height = c.height,
        pitch = c.pitch, sideAngle = c.sideAngle,
        -- trava "prender câmera": qual parte do corpo a câmera mira (ver lockTargets).
        lock = c.defaultLock or "free",
        -- deslocamento vertical (metros) somado à altura do bone travado (ver
        -- resolveTarget); útil quando o bone não fica onde o acessório de fato é
        -- usado (ex.: SKEL_Head fica perto do queixo, abaixo do chapéu/óculos).
        heightOffset = c.heightOffset or 0.0,
        -- deslocamento lateral (metros), perpendicular à direção da câmera (ver
        -- applyCam); útil quando o bone travado não fica no eixo central do ped.
        sideOffset = c.sideOffset or 0.0,
    }
end

--- Devolve a definição de uma trava (entrada de lockTargets) pela sua key, ou nil.
local function lockDefByKey(key)
    for _, def in ipairs(clientConfig.camera.lockTargets or {}) do
        if def.key == key then return def end
    end
    return nil
end

--- Campos que compõem um perfil de câmera (espelham o camState ajustável).
local PROFILE_FIELDS = {
    "fov", "distance", "height", "pitch", "sideAngle", "lock", "heightOffset", "sideOffset",
}

--- Resolve o perfil de uma categoria: base camera.* ⊕ autoProfiles[cat]
--- ⊕ autoOverrides[cat] (override da sessão tem prioridade). Campos ausentes
--- herdam a camada anterior. Retorna uma tabela com todos os PROFILE_FIELDS.
local function profileFor(category)
    local c = clientConfig.camera
    -- camada base (perfil "fixo")
    local out = {
        fov = c.fov, distance = c.distance, height = c.height,
        pitch = c.pitch, sideAngle = c.sideAngle,
        lock = c.defaultLock or "free",
        heightOffset = c.heightOffset or 0.0,
        sideOffset = c.sideOffset or 0.0,
    }
    local function merge(src)
        if type(src) ~= "table" then return end
        for _, f in ipairs(PROFILE_FIELDS) do
            if src[f] ~= nil then out[f] = src[f] end
        end
    end
    local profiles = c.autoProfiles or {}
    merge(profiles.default)
    merge(profiles[category])
    merge(autoOverrides[category])
    return out
end

--- Categorias fotografadas com o PED virado de costas para a câmera (heading do
--- ped + 180°), em vez de girar a câmera para trás dele (câmera atrás do ped
--- pode cair dentro/perto de geometria do mapa perto de estruturas, ocultando
--- tudo por oclusão). Fixo por categoria na config; não é um valor de câmera
--- ajustável ao vivo, por isso fica fora de PROFILE_FIELDS/autoOverrides.
local function turnPedAroundFor(category)
    local profiles = clientConfig.camera.autoProfiles or {}
    local prof = profiles[category]
    return prof and prof.turnPedAround == true
end

-- ----------------------------------------------------------------------------
-- Ped dedicado
-- ----------------------------------------------------------------------------
local function loadModel(model)
    local hash = type(model) == "string" and GetHashKey(model) or model
    RequestModel(hash)
    local tries = 0
    while not HasModelLoaded(hash) and tries < 200 do
        Wait(10); tries = tries + 1
    end
    return hash
end

--- Carrega um dicionário de animação (com timeout). Retorna true se carregou.
local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local tries = 0
    while not HasAnimDictLoaded(dict) and tries < 100 do
        Wait(10); tries = tries + 1
    end
    return HasAnimDictLoaded(dict)
end

--- Aplica a pose neutra configurada ao ped. Por padrão CONGELA num frame, então
--- o ped fica 100% estático (sem respirar/balançar). Sob pcall: se a anim faltar,
--- o ped fica na postura padrão sem derrubar o core.
function capture.applyPose(ped)
    local pose = clientConfig.ped.pose
    if not pose or pose.enabled == false or not pose.dict or not pose.name then
        return
    end

    pcall(function()
        if not loadAnimDict(pose.dict) then
            debugPrint("pose: dict não carregou:", pose.dict)
            return
        end

        -- flag 1 = loop (mantém a pose ativa). Tocamos e, no caso congelado,
        -- fixamos o frame e zeramos a velocidade para não avançar.
        TaskPlayAnim(ped, pose.dict, pose.name, pose.blendIn or 8.0, -8.0, -1, 1, 0.0, false, false, false)

        if pose.freeze ~= false then
            local t = pose.freezeTime or 0.0
            -- espera a anim virar ativa antes de fixar o frame
            local tries = 0
            while not IsEntityPlayingAnim(ped, pose.dict, pose.name, 3) and tries < 30 do
                Wait(0); tries = tries + 1
            end
            SetEntityAnimCurrentTime(ped, pose.dict, pose.name, t)
            -- velocidade 0 = a anim não avança: ped congelado naquele frame
            SetEntityAnimSpeed(ped, pose.dict, pose.name, 0.0)
        end
    end)
end

--- Cria o ped de captura no local isolado. Idempotente.
function capture.spawnPed()
    if capturePed and DoesEntityExist(capturePed) then return capturePed end

    local model = clientConfig.ped.models[gender] or clientConfig.ped.models.male
    local hash = loadModel(model)
    local p = clientConfig.ped.coords

    -- garante o collision do chão carregado ANTES de spawnar e congelar; sem
    -- isso o ped pode nascer flutuando (congela antes da física assentá-lo).
    RequestCollisionAtCoord(p.x, p.y, p.z)
    local tries = 0
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and tries < 100 do
        Wait(10); tries = tries + 1
    end

    -- resolve o Z real do chão naquele x/y (o Z da config pode estar levemente
    -- errado); cai no Z da config se o nativo não encontrar chão.
    local groundZ = p.z
    local found, foundZ = GetGroundZFor_3dCoord(p.x, p.y, p.z + 5.0, false)
    if found then groundZ = foundZ end

    capturePed = CreatePed(4, hash, p.x, p.y, groundZ, clientConfig.ped.heading or p.w, false, true)
    SetEntityInvincible(capturePed, true)
    FreezeEntityPosition(capturePed, true)
    SetBlockingOfNonTemporaryEvents(capturePed, true)
    SetEntityVisible(capturePed, true, false)
    ClearPedDecorations(capturePed)
    SetModelAsNoLongerNeeded(hash)

    -- aplica a roupa base do preset ATIVO (preview por padrão ao spawnar; ver
    -- capture.applyOutfitPreset para trocar entre preview/capture em runtime)
    capture.applyBaseOutfit(capturePed)
    capture.applyPose(capturePed)

    debugPrint("ped de captura criado:", capturePed, "modelo:", model)
    return capturePed
end

--- Troca o gênero/modelo do ped (recria). O realinhamento da câmera à cabeça do
--- novo ped acontece no startCamera() chamado em seguida (ver init: setGender).
function capture.setGender(newGender)
    if newGender ~= "male" and newGender ~= "female" then return end
    if newGender == gender and capturePed and DoesEntityExist(capturePed) then return end
    gender = newGender
    capture.destroyPed()
    capture.spawnPed()
    -- no modo auto, mantém a câmera no perfil da peça em foco após trocar de ped
    if cameraMode == "auto" and activeCategory then
        capture.applyCategoryProfile(activeCategory)
    end
end

function capture.getGender() return gender end

--- Nome do modelo do ped correspondente ao gênero atual.
function capture.getModel()
    return clientConfig.ped.models[gender] or clientConfig.ped.models.male
end

function capture.destroyPed()
    if capturePed and DoesEntityExist(capturePed) then
        DeleteEntity(capturePed)
    end
    capturePed = nil
end

function capture.getPed()
    return capture.spawnPed()
end

-- ----------------------------------------------------------------------------
-- Vestir uma peça
-- ----------------------------------------------------------------------------
--- Aplica (category/slot/drawable/texture) ao ped de captura.
function capture.dress(item)
    local ped = capture.getPed()

    -- garante que a pose continua tocando (reaplica se tiver parado)
    local pose = clientConfig.ped.pose
    if pose and pose.enabled ~= false and pose.dict and pose.name
        and not IsEntityPlayingAnim(ped, pose.dict, pose.name, 3) then
        capture.applyPose(ped)
    end

    if item.isProp then
        SetPedPropIndex(ped, item.slot, item.drawable, item.texture, true)
    else
        SetPedComponentVariation(ped, item.slot, item.drawable, item.texture, 0)
    end
end

--- Resolve os components da roupa base PELO MODELO atual do ped e pelo PRESET
--- ativo (outfitPreset: "preview" ou "capture"). Os índices "mínimo/invisível"
--- diferem entre modelos (masc/fem/addon), então usamos
--- `baseOutfit[preset].byModel[<modelo atual>]` e caímos em
--- `baseOutfit[preset].default`.
---@return table<number, {drawable:number, texture:number}>
local function baseComponents()
    local base = clientConfig.ped.baseOutfit
    if not base or base.enabled == false then return {} end
    local preset = base[outfitPreset] or base.capture or base.preview
    if not preset then return {} end
    local model = clientConfig.ped.models[gender] or clientConfig.ped.models.male
    local entry = (preset.byModel and preset.byModel[model]) or preset.default
    return (entry and entry.components) or {}
end

--- Aplica a roupa base do preset ATIVO ao ped (estado neutro de fundo),
--- resolvida pelo modelo atual. Ver capture.applyOutfitPreset para trocar
--- de preset (preview <-> capture) em runtime.
function capture.applyBaseOutfit(ped)
    local base = clientConfig.ped.baseOutfit
    if not base or base.enabled == false then return end

    for slot, piece in pairs(baseComponents()) do
        SetPedComponentVariation(ped, slot, piece.drawable or 0, piece.texture or 0, 0)
    end

    if base.clearProps then
        for i = 0, 7 do
            ClearPedProp(ped, i)
        end
    end
end

--- Troca o preset de roupa base ativo ("preview" = torso visível p/ ajuste de
--- câmera; "capture" = torso invisível p/ fotografar) e reaplica no ped, se já
--- existir. Seguro chamar repetidamente com o mesmo preset (apenas reaplica).
---@param preset "preview"|"capture"
function capture.applyOutfitPreset(preset)
    if preset ~= "preview" and preset ~= "capture" then return outfitPreset end
    outfitPreset = preset
    if capturePed and DoesEntityExist(capturePed) then
        capture.applyBaseOutfit(capturePed)
    end
    return outfitPreset
end

function capture.getOutfitPreset()
    return outfitPreset
end

--- Estado base de um slot (volta para a roupa base do modelo atual, não um
--- drawable 0 cego).
local function baseComponentFor(slot)
    local piece = baseComponents()[slot]
    if piece then
        return piece.drawable or 0, piece.texture or 0
    end
    return 0, 0
end

--- Reseta a peça de um slot, voltando ao estado base (isola a próxima foto).
function capture.resetSlot(item)
    local ped = capture.getPed()
    if item.isProp then
        ClearPedProp(ped, item.slot)
    else
        local drawable, texture = baseComponentFor(item.slot)
        SetPedComponentVariation(ped, item.slot, drawable, texture, 0)
    end
end

-- ----------------------------------------------------------------------------
-- Câmera
-- ----------------------------------------------------------------------------
--- Resolve o ALVO que a câmera deve mirar, conforme a trava (camState.lock).
--- Devolve tx, ty, tz (coords mundiais).
---  - bone válido  -> posição mundial do bone (ex.: cabeça, peito), deslocada
---    verticalmente por camState.heightOffset (ver capture.applyCategoryProfile
---    e o campo `heightOffset` dos autoProfiles). Necessário porque o bone da
---    cabeça fica perto do queixo/pescoço, abaixo de onde chapéu/óculos ficam
---    de fato — sem o offset, a mira cai baixa demais para esses acessórios.
---  - bone lateral (ex.: pé esquerdo) -> só a altura (z) do bone; x/y ficam no
---    centro do ped (base), senão girar sideAngle ao redor do ped deixa o alvo
---    (fora do eixo central) fugir do centro da tela.
---  - fullBody      -> ponto médio entre os pés (base) e a cabeça.
---  - free/inválido -> centro do ped (base x/y) na altura manual (base.z + height).
--- Modelos sem o bone caem no alvo manual com segurança.
local function resolveTarget(ped, base)
    local def = lockDefByKey(camState.lock)

    if def and def.bone then
        local idx = GetPedBoneIndex(ped, def.bone)
        if idx ~= -1 then
            local p = GetWorldPositionOfEntityBone(ped, idx)
            local z = p.z + (camState.heightOffset or 0.0)
            if def.centerXY then
                return base.x, base.y, z
            end
            return p.x, p.y, z
        end
    elseif def and def.fullBody then
        local headIdx = GetPedBoneIndex(ped, 31086) -- SKEL_Head
        if headIdx ~= -1 then
            local head = GetWorldPositionOfEntityBone(ped, headIdx)
            return base.x, base.y, (base.z + head.z) / 2.0
        end
    end

    -- free (ou bone ausente): alvo manual controlado pelo slider de altura.
    return base.x, base.y, base.z + camState.height
end

--- Recalcula a posição da câmera a partir do camState e do ped.
--- A câmera fica DE FRENTE para o ped: na direção em que o ped olha (forward do
--- ped), a `distance` metros. forward = (-sin(h), cos(h)). sideAngle gira a
--- câmera ao redor do ped (0 = de frente). O PONTO mirado vem da trava (ver
--- resolveTarget): cabeça/peito/etc. ou a altura manual quando "free".
---
--- camState.sideOffset desloca CÂMERA e ALVO juntos no eixo lateral (perpendicular
--- ao forward, "direita" de quem olha o ped), preservando distância/ângulo — usado
--- para recentralizar um item cujo bone não fica no eixo central do ped.
local function applyCam()
    if not cam then return end
    local ped = capture.getPed()
    local base = GetEntityCoords(ped)
    local heading = math.rad((clientConfig.ped.heading or 0.0) + camState.sideAngle)

    local tx, ty, targetZ = resolveTarget(ped, base)

    -- eixo lateral = forward rotacionado 90°: (cos(h), sin(h))
    local sideOffset = camState.sideOffset or 0.0
    local ox = math.cos(heading) * sideOffset
    local oy = math.sin(heading) * sideOffset
    tx = tx + ox
    ty = ty + oy

    -- posição na frente do ped (forward): base + forward * distance
    local cx = base.x - math.sin(heading) * camState.distance + ox
    local cy = base.y + math.cos(heading) * camState.distance + oy
    local cz = targetZ + math.tan(math.rad(camState.pitch)) * camState.distance

    -- Os nativos de câmera esperam FLOAT. Valores vindos da NUI (JSON) chegam como
    -- INTEIRO quando não têm casa decimal (ex.: fov 32, sideAngle 90), e passar um
    -- inteiro a SetCamFov/SetCamCoord distorce o enquadramento (zoom errado). O
    -- `+ 0.0` força float em tudo que entra nos nativos — barreira única para
    -- qualquer origem (NUI, teclas, config).
    SetCamCoord(cam, cx + 0.0, cy + 0.0, cz + 0.0)
    PointCamAtCoord(cam, tx + 0.0, ty + 0.0, targetZ + 0.0)
    SetCamFov(cam, camState.fov + 0.0)
end

--- Aplica o perfil resolvido de uma categoria ao camState ao vivo e reaplica a
--- câmera. resolveTarget/applyCam já miram o bone de camState.lock, então a
--- câmera reposiciona sozinha para a parte certa do corpo.
---
--- Categorias com turnPedAround (ex.: backpack) giram o PED 180° em vez da
--- câmera: a câmera permanece sempre no mesmo espaço físico (na frente do local
--- isolado), evitando cair atrás do ped — onde estruturas/paredes próximas podem
--- ocluir tudo. Ver turnPedAroundFor.
---@param category string
---@return table camState
function capture.applyCategoryProfile(category)
    camState = camState or freshCamState()
    activeCategory = category
    local p = profileFor(category)

    local ped = capture.getPed()
    local baseHeading = clientConfig.ped.heading or 0.0
    SetEntityHeading(ped, turnPedAroundFor(category) and (baseHeading + 180.0) % 360 or baseHeading)

    camState.fov = p.fov + 0.0
    camState.distance = p.distance + 0.0
    camState.height = p.height + 0.0
    camState.pitch = p.pitch + 0.0
    camState.sideAngle = (p.sideAngle or 0.0) % 360
    camState.lock = lockDefByKey(p.lock) and p.lock or (camState.lock or "free")
    camState.heightOffset = (p.heightOffset or 0.0) + 0.0
    camState.sideOffset = (p.sideOffset or 0.0) + 0.0
    applyCam()
    return camState
end

function capture.getActiveCategory()
    return activeCategory
end

--- Define em qual parte do corpo a câmera fica "presa" (ver lockTargets na
--- config). A câmera passa a mirar o bone correspondente continuamente — o
--- applyCam reaplica a cada ajuste/troca de ped. Key inválida é ignorada.
---@param key string  ex.: "head", "chest", "free"
function capture.setLock(key)
    camState = camState or freshCamState()
    if not lockDefByKey(key) then return camState end
    camState.lock = key
    applyCam()
    if cameraMode == "auto" and activeCategory then
        capture.saveCategoryProfile(activeCategory)
    end
    return camState
end

function capture.getLock()
    return (camState and camState.lock) or clientConfig.camera.defaultLock or "free"
end

--- Lista ordenada das keys de trava (para popular o dropdown da NUI). Os labels
--- são montados na NUI via locale (lock<Key>), mantendo só as keys aqui.
function capture.getLockKeys()
    local keys = {}
    for _, def in ipairs(clientConfig.camera.lockTargets or {}) do
        keys[#keys + 1] = def.key
    end
    return keys
end

--- Liga a câmera de captura (cria se preciso) e o preview.
function capture.startCamera()
    if not camState then camState = freshCamState() end
    capture.spawnPed()

    if not cam then
        cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    end
    -- applyCam já mira o alvo da trava atual (camState.lock), realinhando à parte
    -- escolhida do ped — inclusive na abertura e após troca de ped. No modo auto,
    -- a abertura já aplica o perfil da categoria em foco.
    if cameraMode == "auto" then
        capture.applyCategoryProfile(activeCategory or capture.defaultActiveCategory())
    else
        applyCam()
    end
    RenderScriptCams(true, false, 0, true, true)
    framing.setOverlay(true)
end

--- Desliga a câmera e o preview, devolvendo a render ao jogador.
function capture.stopCamera()
    framing.setOverlay(false)
    RenderScriptCams(false, false, 0, true, true)
    if cam then
        DestroyCam(cam, false)
        cam = nil
    end
end

--- Ajusta um parâmetro da câmera ao vivo, respeitando limites.
---@param field "fov"|"distance"|"height"|"pitch"|"sideAngle"
---@param delta number
function capture.adjust(field, delta)
    if not camState then camState = freshCamState() end
    local limits = clientConfig.camera.limits
    camState[field] = (camState[field] or 0) + delta

    if field == "sideAngle" then
        camState.sideAngle = camState.sideAngle % 360
    elseif limits[field] then
        camState[field] = clamp(camState[field], limits[field].min, limits[field].max)
    end
    applyCam()
    if cameraMode == "auto" and activeCategory then
        capture.saveCategoryProfile(activeCategory)
    end
    return camState
end

--- Define o camState diretamente (vindo da UI). Aplica limites.
--- A NUI envia números via JSON; sem casa decimal eles chegam como INTEIRO. O
--- `+ 0.0` normaliza para float já na entrada, mantendo o camState consistente
--- (clamp e os nativos em applyCam contam com float).
function capture.setCamState(newState)
    camState = camState or freshCamState()
    local limits = clientConfig.camera.limits
    for _, f in ipairs({ "fov", "distance", "height", "pitch", "heightOffset", "sideOffset" }) do
        if type(newState[f]) == "number" and limits[f] then
            camState[f] = clamp(newState[f] + 0.0, limits[f].min, limits[f].max)
        end
    end
    if type(newState.sideAngle) == "number" then
        camState.sideAngle = (newState.sideAngle + 0.0) % 360
    end
    applyCam()
    -- modo auto: o ajuste do operador vira override da categoria em foco
    if cameraMode == "auto" and activeCategory then
        capture.saveCategoryProfile(activeCategory)
    end
    return camState
end

function capture.resetCamera()
    if cameraMode == "auto" and activeCategory then
        -- limpa o override e volta ao perfil de config da categoria
        autoOverrides[activeCategory] = nil
        return capture.applyCategoryProfile(activeCategory)
    end
    camState = freshCamState()
    applyCam()
    return camState
end

function capture.getCamState()
    return camState or freshCamState()
end

-- ----------------------------------------------------------------------------
-- Modo da câmera (auto = perfil por categoria; fixed = câmera única)
-- ----------------------------------------------------------------------------
function capture.getCameraMode()
    return cameraMode
end

--- Categoria ativa padrão quando nenhuma foi escolhida ainda: a primeira da
--- ORDER, senão "default".
function capture.defaultActiveCategory()
    local order = shared.constants.ORDER or {}
    return order[1] or "default"
end

--- Alterna o modo da câmera. Em "auto", reaplica o perfil da categoria ativa
--- (ou a primeira categoria/`default`). Em "fixed", volta ao camState base.
---@param mode "auto"|"fixed"
---@return string mode
function capture.setCameraMode(mode)
    if mode ~= "auto" and mode ~= "fixed" then return cameraMode end
    cameraMode = mode
    if mode == "fixed" then
        camState = freshCamState()
        -- modo fixo não tem "categoria ativa" para decidir virar o ped ou não;
        -- garante que ele não fique preso de costas de uma troca anterior (ex.:
        -- vinha da categoria backpack, que usa turnPedAround).
        local ped = capture.getPed()
        SetEntityHeading(ped, clientConfig.ped.heading or 0.0)
        applyCam()
    else
        capture.applyCategoryProfile(activeCategory or capture.defaultActiveCategory())
    end
    return cameraMode
end

--- Salva o camState atual como override de uma categoria (na sessão). Só guarda
--- os PROFILE_FIELDS. Não persiste em arquivo (escopo desta versão).
---@param category string
---@return boolean
function capture.saveCategoryProfile(category)
    if type(category) ~= "string" or category == "" then return false end
    camState = camState or freshCamState()
    autoOverrides[category] = {
        fov = camState.fov, distance = camState.distance, height = camState.height,
        pitch = camState.pitch, sideAngle = camState.sideAngle, lock = camState.lock,
        heightOffset = camState.heightOffset, sideOffset = camState.sideOffset,
    }
    return true
end

-- ----------------------------------------------------------------------------
-- Foto: screenshot -> recorte quadrado na NUI -> gravação no server
-- ----------------------------------------------------------------------------

--- Nome do primeiro recurso de screenshot que estiver iniciado, ou nil.
local function clientScreenshotResource()
    for _, name in ipairs(shared.config.screenshotResources or { "screenshot-basic" }) do
        if GetResourceState(name) == "started" then
            return name
        end
    end
    return nil
end

--- Fotografa a peça já vestida e manda o resultado ao server para gravar.
--- Bloqueia a thread até terminar, então só pode ser chamada de dentro de uma.
---
--- A captura é feita aqui no client (data URI), e não pelo fluxo server-side do
--- screenshot-basic, porque esse faz upload para um arquivo temporário que o
--- sandbox de filesystem do FiveM bloqueia.
---@param item table
---@return boolean ok
---@return string|nil result caminho da foto salva (relativo à pasta de saída) ou o motivo da falha
function capture.shoot(item)
    local screenshot = clientScreenshotResource()
    if not screenshot then
        return false, "nenhum recurso de screenshot iniciado"
    end

    local crop = framing.computeCrop()

    -- captura client-side: o callback recebe um data URI base64
    local dataUri = nil
    local captured = false
    local ok = pcall(function()
        exports[screenshot]:requestScreenshot({
            encoding = shared.config.image.encoding,
            quality = shared.config.image.quality,
        }, function(data)
            dataUri = data
            captured = true
        end)
    end)

    if not ok then
        return false, "exceção ao capturar no client"
    end

    -- aguarda o callback do screenshot (timeout de segurança)
    local waited = 0
    while not captured and waited < 15000 do
        Wait(25); waited = waited + 25
    end

    if not captured or type(dataUri) ~= "string" then
        return false, "timeout na captura"
    end

    -- A NUI recorta a tela cheia num quadrado size x size, seguindo o quadro-guia.
    ticketSeq = ticketSeq + 1
    local cropTicket = ticketSeq
    local croppedUri = nil
    local cropDone = false
    pendingCrops[cropTicket] = function(img)
        if cropDone then return end
        cropDone = true
        croppedUri = img
    end

    nuiSend("crop", {
        ticket = cropTicket,
        image = dataUri,
        crop = crop,
        size = shared.config.image.size or 512,
        encoding = shared.config.image.encoding,
        quality = shared.config.image.quality,
    })

    waited = 0
    while not cropDone and waited < 10000 do
        Wait(25); waited = waited + 25
    end
    pendingCrops[cropTicket] = nil

    if not cropDone or type(croppedUri) ~= "string" then
        return false, "timeout no recorte"
    end

    -- A imagem já está recortada, então o crop registrado no index.json cobre a
    -- imagem inteira.
    ticketSeq = ticketSeq + 1
    local ticket = ticketSeq
    local result = nil
    pendingShots[ticket] = function(rok, data)
        if result ~= nil then return end
        result = { ok = rok, data = data }
    end

    TriggerServerEvent("dk_autophoto:server:saveShot", {
        ticket = ticket,
        category = item.category,
        slot = item.slot,
        drawable = item.drawable,
        texture = item.texture,
        gender = gender,
        model = clientConfig.ped.models[gender] or clientConfig.ped.models.male,
        crop = { x = 0, y = 0, w = 1, h = 1 },
        image = croppedUri,
    })

    waited = 0
    while result == nil and waited < 15000 do
        Wait(25); waited = waited + 25
    end

    pendingShots[ticket] = nil

    if result == nil then
        return false, "timeout ao salvar"
    end
    return result.ok, result.data
end

--- Recebe a resposta do server à gravação (evento shotResult, em init.lua).
function capture.resolveShot(ticket, ok, data)
    local resolver = pendingShots[ticket]
    if resolver then resolver(ok, data) end
end

--- Recebe a imagem recortada da NUI (callback `cropped`, em init.lua).
function capture.resolveCrop(ticket, image)
    local resolver = pendingCrops[ticket]
    if resolver then resolver(image) end
end

-- ----------------------------------------------------------------------------
-- Cleanup
-- ----------------------------------------------------------------------------
function capture.cleanup()
    capture.stopCamera()
    capture.destroyPed()
    pendingShots = {}
    pendingCrops = {}
end

Autophoto.register("client.capture", capture)
return capture
