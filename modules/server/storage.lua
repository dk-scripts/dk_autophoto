-- ============================================================================
-- Storage: grava no disco a foto que o client capturou
--
-- A captura é feita no client (modules/client/capture.lua) e chega aqui como data
-- URI base64. O server decodifica e grava o arquivo dentro de `output.dir`.
--
-- Por que a gravação tem várias tentativas: o SaveResourceFile do FiveM não cria
-- pastas, e `output.path` costuma ter subpastas ({sex}/{part}/...). Então criamos a
-- árvore antes com `mkdir` (via io.popen) e gravamos em seguida. Se o host bloquear
-- o io.popen, a foto é salva na raiz de `output.dir`, com "_" no lugar das barras.
-- ============================================================================

local shared = Autophoto.use("shared")
local serverConfig = Autophoto.use("config.server")
local utils = shared.utils

local storage = {}

local DEFAULT_DIR = "output"
local DEFAULT_PATH = "{part}_{variation}_{color}.{ext}"

local function outputDir()
    return serverConfig.output.dir or DEFAULT_DIR
end

--- Deixa só letras, números, "-" e "_". Os pontos também saem: os valores que
--- entram no caminho vêm do client, e ".." escaparia da pasta de saída.
local function sanitize(value)
    return (tostring(value):gsub("[^%w%-_]", "_"))
end

--- Resolve `output.path` para o caminho de uma peça, relativo a `output.dir`.
--- Padrão desconhecido no template vira texto vazio.
---@param info table { category, slot, drawable, texture, gender, model }
---@return string path ex.: "mp_m_freemode_01/backpack/0_0.webp"
function storage.pathFor(info)
    local ext = shared.config.image.encoding or "webp"
    local template = serverConfig.output.path or DEFAULT_PATH

    local values = {
        sex = sanitize(info.model or info.gender or "ped"),
        gender = sanitize(info.gender or "male"),
        part = sanitize(info.category or "part"),
        slot = sanitize(info.slot or 0),
        variation = sanitize(info.drawable or 0),
        color = sanitize(info.texture or 0),
        ext = sanitize(ext),
    }

    local resolved = template:gsub("{(%w+)}", function(key)
        return values[key] or ""
    end)

    resolved = resolved:gsub("\\", "/"):gsub("//+", "/"):gsub("^/", "")
    return resolved
end

--- Caminho de um arquivo de saída relativo ao recurso, que é o que o
--- SaveResourceFile espera.
function storage.resourcePathFor(path)
    return outputDir() .. "/" .. path
end

-- Pasta de saída absoluta, resolvida uma vez.
local absoluteOutputDir
local function resolveAbsoluteOutputDir()
    if absoluteOutputDir ~= nil then return absoluteOutputDir end

    local base = GetResourcePath(GetCurrentResourceName())
    if not base or base == "" then
        absoluteOutputDir = false
        return false
    end

    base = base:gsub("\\", "/"):gsub("//+", "/"):gsub("/+$", "")
    absoluteOutputDir = base .. "/" .. outputDir()
    return absoluteOutputDir
end

-- Pastas já criadas nesta sessão, para não rodar o mkdir a cada foto.
local ensuredDirs = {}

local popenWarned = false
local function warnPopenOnce(reason)
    if popenWarned then return end
    popenWarned = true
    print(("^3[dk_autophoto]^0 não consegui criar as subpastas (%s). As fotos serão salvas direto em %s/."):format(reason, outputDir()))
end

--- Cria a árvore de pastas `absDir` com o mkdir do sistema. Devolve false se o
--- io.popen não estiver disponível.
local function makeDirs(absDir)
    if not io or not io.popen then
        warnPopenOnce("io.popen indisponível")
        return false
    end

    -- No Windows o `mkdir` do cmd já cria a árvore inteira; no Linux precisa do -p.
    local isWindows = absDir:match("^%a:[/\\]") ~= nil
    local command
    if isWindows then
        command = ('cmd /c mkdir "%s"'):format((absDir:gsub("/", "\\")))
    else
        command = ('mkdir -p "%s"'):format(absDir)
    end

    local ok, handle = pcall(io.popen, command)
    if not ok or not handle then
        warnPopenOnce(ok and "io.popen não devolveu um processo" or tostring(handle))
        return false
    end

    -- Ler a saída faz esperar o processo terminar antes de fechar.
    handle:read("*a")
    handle:close()
    return true
end

local function ensureDir(absDir)
    if not absDir or absDir == "" or ensuredDirs[absDir] then return end
    makeDirs(absDir)
    ensuredDirs[absDir] = true
end

-- Caminho do recurso a partir de "resources/", relativo à pasta do server. Alguns
-- hosts barram o io.open com caminho absoluto, mas aceitam o relativo.
local relativeResourceDir
local function resolveRelativeResourceDir()
    if relativeResourceDir ~= nil then return relativeResourceDir end

    local absolute = (GetResourcePath(GetCurrentResourceName()) or ""):gsub("\\", "/"):gsub("//+", "/"):gsub("/+$", "")
    relativeResourceDir = absolute:match("(resources/.+)$") or false
    return relativeResourceDir
end

local writeWarned = {}

--- Grava os bytes com io.open, primeiro pelo caminho absoluto e depois pelo
--- relativo. Cada tipo de falha é avisado uma única vez no console.
local function writeBinary(absolutePath, path, binary)
    local file, err = io.open(absolutePath, "wb")
    if file then
        file:write(binary)
        file:close()
        return true
    end
    if not writeWarned.absolute then
        writeWarned.absolute = true
        print(("^3[dk_autophoto]^0 io.open (caminho absoluto) falhou: %s"):format(tostring(err)))
    end

    local relativeDir = resolveRelativeResourceDir()
    if not relativeDir then return false end

    local relativePath = relativeDir .. "/" .. outputDir() .. "/" .. path
    local relativeFile, relativeErr = io.open(relativePath, "wb")
    if relativeFile then
        relativeFile:write(binary)
        relativeFile:close()
        return true
    end
    if not writeWarned.relative then
        writeWarned.relative = true
        print(("^3[dk_autophoto]^0 io.open (caminho relativo %s) falhou: %s"):format(relativePath, tostring(relativeErr)))
    end

    return false
end

--- Grava a foto de uma peça a partir do data URI recebido do client.
---@param info table { category, slot, drawable, texture, gender, model }
---@param dataUri string "data:image/webp;base64,..."
---@param done fun(ok: boolean, result: table|string) result = { path } ou o motivo da falha
function storage.save(info, dataUri, done)
    local path = storage.pathFor(info)

    local base64 = utils.dataUriToBase64(dataUri)
    if not base64 then
        return done(false, "data uri inválido")
    end

    local binary = utils.b64decode(base64)
    if #binary == 0 then
        print(("^1[dk_autophoto]^0 decode vazio para %s"):format(path))
        return done(false, "decode vazio")
    end

    local absoluteDir = resolveAbsoluteOutputDir()
    if not absoluteDir then
        return done(false, "GetResourcePath vazio")
    end

    local absolutePath = absoluteDir .. "/" .. path
    ensureDir(absolutePath:match("^(.*)/[^/]+$"))

    local resourceName = GetCurrentResourceName()

    -- 1) SaveResourceFile: grava se a subpasta já existir.
    if SaveResourceFile(resourceName, storage.resourcePathFor(path), binary, #binary) then
        return done(true, { path = path })
    end

    -- 2) io.open, caso o SaveResourceFile não grave em subpasta neste host.
    if writeBinary(absolutePath, path, binary) then
        return done(true, { path = path })
    end

    -- 3) Sem subpasta: salva na raiz de `output.dir`.
    local flatPath = path:gsub("/", "_")
    if SaveResourceFile(resourceName, storage.resourcePathFor(flatPath), binary, #binary) then
        print(("^3[dk_autophoto]^0 subpasta indisponível; salvei sem subpasta: %s"):format(flatPath))
        return done(true, { path = flatPath })
    end

    print(("^1[dk_autophoto]^0 falha ao salvar %s"):format(path))
    return done(false, "save_failed")
end

Autophoto.register("server.storage", storage)
return storage
