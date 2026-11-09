-- ============================================================================
-- Manifest: o output/index.json, que lista as fotos já geradas
--
-- Estrutura:
-- {
--   "resource": "dk_autophoto",
--   "generatedAt": 1718999999,
--   "photos": {
--     "mp_m_freemode_01": {
--       "torso": {
--         "4": {
--           "0": {
--             "path": "mp_m_freemode_01/torso/4_0.webp",
--             "crop": { "x": 0, "y": 0, "w": 1, "h": 1 }
--           }
--         }
--       }
--     }
--   }
-- }
--
-- Os níveis são modelo > categoria > drawable > textura. `path` é relativo a
-- `output.dir`. O arquivo é criado na primeira foto salva.
--
-- Mantemos o conteúdo em memória e gravamos no disco depois de 1 segundo sem
-- novas fotos, em vez de gravar a cada foto.
-- ============================================================================

local serverConfig = Autophoto.use("config.server")

local manifest = {}

local indexFile = (serverConfig.output.dir or "output") .. "/index.json"

local data = nil
local dirty = false
local flushScheduled = false

--- Carrega o index do disco. Se ainda não existir (ou estiver ilegível), começa vazio.
local function load()
    if data then return data end

    local raw = LoadResourceFile(GetCurrentResourceName(), indexFile)
    if raw and raw ~= "" then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == "table" then
            data = decoded
            data.photos = data.photos or {}
            return data
        end
    end

    data = { resource = GetCurrentResourceName(), generatedAt = os.time(), photos = {} }
    return data
end

local function flush()
    if not dirty then return end

    local current = load()
    current.generatedAt = os.time()
    SaveResourceFile(GetCurrentResourceName(), indexFile, json.encode(current), -1)
    dirty = false
end

local function scheduleFlush()
    dirty = true
    if flushScheduled then return end

    flushScheduled = true
    SetTimeout(1000, function()
        flushScheduled = false
        flush()
    end)
end

--- Registra (ou atualiza) uma foto.
---@param model string
---@param category string
---@param drawable integer
---@param texture integer
---@param path string caminho relativo a `output.dir`
---@param crop table
function manifest.set(model, category, drawable, texture, path, crop)
    local node = load().photos
    for _, key in ipairs({ model, category, tostring(drawable) }) do
        node[key] = node[key] or {}
        node = node[key]
    end

    node[tostring(texture)] = { path = path, crop = crop }
    scheduleFlush()
end

--- Devolve o caminho de uma foto, ou nil se ela não existir.
---@param model string
---@param category string
---@param drawable integer
---@param texture integer
---@return string|nil
function manifest.get(model, category, drawable, texture)
    local node = load().photos
    for _, key in ipairs({ model, category, tostring(drawable), tostring(texture) }) do
        node = node[key]
        if not node then return nil end
    end

    return node.path
end

--- Devolve o manifest inteiro.
function manifest.getAll()
    return load()
end

--- Grava no disco agora, sem esperar o debounce (fim da sessão e parada do recurso).
function manifest.flushNow()
    flush()
end

Autophoto.register("server.manifest", manifest)
return manifest
