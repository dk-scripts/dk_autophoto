-- ============================================================================
-- Orquestrador do server: eventos de foto, logs, exports e hooks
-- ============================================================================

local shared = Autophoto.use("shared")
local serverConfig = Autophoto.use("config.server")
local storage = Autophoto.use("server.storage")
local manifest = Autophoto.use("server.manifest")
local commands = Autophoto.use("server.commands")
local utils = shared.utils

local server = {}

-- Modelo usado pelo export getPhoto quando quem chama não informa um.
local DEFAULT_MODEL = "mp_m_freemode_01"

-- ----------------------------------------------------------------------------
-- Logs: no console e, se configurado, no webhook (que fica só no config do server)
-- ----------------------------------------------------------------------------
local function log(category, message)
    if not serverConfig.logs.enabled then return end
    if serverConfig.logs.categories[category] == false then return end

    print(("[dk_autophoto][%s] %s"):format(category, message))

    local webhook = serverConfig.logs.webhook
    if webhook and webhook ~= "" then
        local payload = json.encode({
            username = "dk_autophoto",
            embeds = {
                {
                    title = category,
                    description = message,
                    color = 8146943,
                },
            },
        })

        -- Uma falha do webhook não pode derrubar o recurso.
        pcall(function()
            PerformHttpRequest(webhook, function() end, "POST", payload, { ["Content-Type"] = "application/json" })
        end)
    end
end

local function runHook(name, ...)
    local fn = serverConfig.hooks and serverConfig.hooks[name]
    return utils.safeCall("hook." .. name, fn, nil, ...)
end

-- ----------------------------------------------------------------------------
-- Eventos vindos do client
--
-- Os eventos são públicos: qualquer client pode dispará-los, então cada um confere
-- a permissão e valida o payload antes de gravar qualquer coisa.
-- ----------------------------------------------------------------------------

local function isValidShot(req)
    return type(req) == "table"
        and type(req.ticket) == "number"
        and type(req.category) == "string"
        and shared.constants.CATEGORIES[req.category] ~= nil
        and utils.isUint(req.drawable)
        and utils.isUint(req.texture)
        and (req.gender == "male" or req.gender == "female")
        and type(req.model) == "string"
        and req.model:match("^[%w_%-]+$") ~= nil
        and type(req.crop) == "table"
        and type(req.image) == "string"
end

RegisterNetEvent("dk_autophoto:server:saveShot", function(req)
    local src = source
    local ticket = type(req) == "table" and req.ticket or nil

    if not commands.canUse(src) then
        TriggerClientEvent("dk_autophoto:client:shotResult", src, ticket, false, "no_permission")
        return
    end

    if not isValidShot(req) then
        TriggerClientEvent("dk_autophoto:client:shotResult", src, ticket, false, "bad_request")
        return
    end

    local piece = {
        category = req.category,
        slot = utils.isUint(req.slot) and req.slot or 0,
        drawable = req.drawable,
        texture = req.texture,
        gender = req.gender,
        model = req.model,
    }

    storage.save(piece, req.image, function(ok, result)
        if ok then
            manifest.set(req.model, req.category, req.drawable, req.texture, result.path, req.crop)
            TriggerClientEvent("dk_autophoto:client:shotResult", src, req.ticket, true, result.path)
            return
        end

        local reason = tostring(result)
        log("errors", ("falha na foto %s: %s"):format(utils.fileKey(req.category, req.drawable, req.texture), reason))
        runHook("onError", src, reason)
        TriggerClientEvent("dk_autophoto:client:shotResult", src, req.ticket, false, reason)
    end)
end)

RegisterNetEvent("dk_autophoto:server:sessionStart", function()
    local src = source
    if not commands.canUse(src) then return end

    log("session", ("player %d iniciou uma sessão de captura"):format(src))
    runHook("onSessionStart", src)
end)

RegisterNetEvent("dk_autophoto:server:captureComplete", function(stats)
    local src = source
    if not commands.canUse(src) then return end
    if type(stats) ~= "table" then return end

    local total = tonumber(stats.total) or 0
    local saved = tonumber(stats.saved) or 0
    local failed = tonumber(stats.failed) or 0

    manifest.flushNow()
    log("session", ("player %d concluiu: %d salvas, %d falhas (de %d)"):format(src, saved, failed, total))
    runHook("onComplete", src, {
        total = total,
        saved = saved,
        failed = failed,
    })
end)

-- ----------------------------------------------------------------------------
-- Exports (contrato público; documentados no README)
-- ----------------------------------------------------------------------------
exports("getManifest", function()
    return manifest.getAll()
end)

exports("getPhoto", function(category, drawable, texture, model)
    if type(category) ~= "string" then return nil end

    return manifest.get(
        type(model) == "string" and model or DEFAULT_MODEL,
        category,
        tonumber(drawable) or 0,
        tonumber(texture) or 0
    )
end)

exports("isReady", function()
    for _, name in ipairs(shared.config.screenshotResources or { "screenshot-basic" }) do
        if GetResourceState(name) == "started" then return true end
    end
    return false
end)

-- ----------------------------------------------------------------------------
-- Cleanup
-- ----------------------------------------------------------------------------
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    manifest.flushNow()
end)

Autophoto.register("server.init", server)
return server
