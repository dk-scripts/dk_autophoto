-- ============================================================================
-- Utilitários compartilhados (sem dependências externas)
-- ============================================================================

local sharedConfig = Autophoto.use("config.shared")

local utils = {}

--- debugPrint respeita config.shared.debug.enabled.
function utils.debugPrint(...)
    if not sharedConfig.debug.enabled then return end
    print("[dk_autophoto]", ...)
end

--- Chave interna de uma peça ("<category>_<drawable>_<texture>"), usada na fila e
--- nos logs. Não é o nome do arquivo: este vem de config.server.output.path.
---@param category string
---@param drawable integer
---@param texture integer
---@return string
function utils.fileKey(category, drawable, texture)
    return ("%s_%d_%d"):format(category, drawable, texture)
end

--- Chave única de um item na fila.
function utils.itemKey(item)
    return utils.fileKey(item.category, item.drawable, item.texture)
end

--- Limita um número a [min, max].
function utils.clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

--- Executa fn sob pcall; em erro, loga via debugPrint e devolve fallback.
--- Usado para rodar hooks/callbacks do cliente final sem derrubar o core.
---@param label string
---@param fn function
---@param fallback any
function utils.safeCall(label, fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end

    local ok, result = pcall(fn, ...)
    if not ok then
        utils.debugPrint("erro em", label, "->", result)
        return fallback
    end

    return result
end

--- Valida que value é inteiro >= 0.
function utils.isUint(value)
    return type(value) == "number" and value >= 0 and math.floor(value) == value
end

-- ----------------------------------------------------------------------------
-- Base64 decode (server): o client envia a foto como data URI e o server precisa
-- dos bytes para gravar o arquivo. O Lua do FiveM não traz um decoder, então
-- incluímos um pequeno.
-- ----------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64lookup
local function buildLookup()
    if b64lookup then return end
    b64lookup = {}
    for i = 1, #B64 do
        b64lookup[B64:byte(i)] = i - 1
    end
end

--- Decodifica uma string base64 para a string binária correspondente.
--- Ignora caracteres fora do alfabeto (whitespace, etc.) e o padding "=".
--- Usa operadores bitwise do Lua 5.4 e mantém o acumulador limitado a 6+ bits
--- (sem deixar o buffer crescer indefinidamente em imagens grandes).
---@param input string
---@return string
function utils.b64decode(input)
    buildLookup()
    local bytes = {}
    local bitsBuffer, bitsCount = 0, 0
    local n = 0

    for i = 1, #input do
        local v = b64lookup[input:byte(i)]
        if v then
            bitsBuffer = (bitsBuffer << 6) | v
            bitsCount = bitsCount + 6
            if bitsCount >= 8 then
                bitsCount = bitsCount - 8
                local byte = (bitsBuffer >> bitsCount) & 0xFF
                n = n + 1
                bytes[n] = string.char(byte)
                -- mantém só os `bitsCount` bits restantes no buffer
                bitsBuffer = bitsBuffer & ((1 << bitsCount) - 1)
            end
        end
    end

    return table.concat(bytes)
end

--- Extrai a parte base64 de um data URI "data:<mime>;base64,<dados>".
---@param dataUri string
---@return string|nil
function utils.dataUriToBase64(dataUri)
    if type(dataUri) ~= "string" then return nil end
    local payload = dataUri:match("^data:[^,]*,(.+)$")
    return payload or dataUri
end

Autophoto.register("utils", utils)
return utils
