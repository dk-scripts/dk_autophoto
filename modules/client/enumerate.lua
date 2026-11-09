-- ============================================================================
-- Enumerate: monta a lista de itens (category, drawable, texture) a fotografar
--
-- Lê do próprio ped (já com o modelo correto) quantos drawables/texturas cada
-- categoria tem, usando as APIs corretas para component vs prop.
-- ============================================================================

local shared = Autophoto.use("shared")
local C = shared.constants
local sharedConfig = shared.config

local enumerate = {}

--- Quantos drawables a categoria tem no ped.
local function drawableCount(ped, def)
    if def.isProp then
        -- props: índice -1 é "nenhum"; count exclui isso
        return GetNumberOfPedPropDrawableVariations(ped, def.slot)
    end
    return GetNumberOfPedDrawableVariations(ped, def.slot)
end

--- Quantas texturas um drawable específico tem.
local function textureCount(ped, def, drawable)
    if def.isProp then
        return GetNumberOfPedPropTextureVariations(ped, def.slot, drawable)
    end
    return GetNumberOfPedTextureVariations(ped, def.slot, drawable)
end

--- Resolve quantas texturas capturar conforme config.shared.textures.
---@param available integer
---@return integer count  (sempre >= 1)
local function texturesToCapture(available)
    if available < 1 then available = 1 end

    local mode = sharedConfig.textures
    if mode == "all" then
        return available
    elseif type(mode) == "table" and type(mode.max) == "number" then
        local m = math.floor(mode.max)
        if m < 1 then m = 1 end
        return math.min(m, available)
    end
    -- "first" (default)
    return 1
end

--- Conta quantos drawables cada categoria tem no ped atual (já vestido).
---@param ped integer
---@return table<string, integer>  -- category -> count
function enumerate.counts(ped)
    local out = {}
    for _, category in ipairs(C.ORDER) do
        local def = C.CATEGORIES[category]
        if def then
            local n = drawableCount(ped, def)
            out[category] = n > 0 and n or 0
        end
    end
    return out
end

--- Monta a fila de itens para as categorias selecionadas.
---@param ped integer
---@param selected table<string, true|integer[]>  -- categoria -> true (todas) | lista de drawables
---@return table items  -- lista { category, slot, isProp, drawable, texture }
function enumerate.build(ped, selected)
    local items = {}

    --- Enfileira um drawable (com suas texturas conforme config) se válido.
    local function addDrawable(category, def, drawable, count)
        if drawable < 0 or drawable > count - 1 then return end  -- clamp defensivo
        local texAvail = textureCount(ped, def, drawable)
        local texN = texturesToCapture(texAvail)
        for texture = 0, texN - 1 do
            items[#items + 1] = {
                category = category,
                slot = def.slot,
                isProp = def.isProp,
                drawable = drawable,
                texture = texture,
            }
        end
    end

    local function addCategory(category, which)
        local def = C.CATEGORIES[category]
        if not def then return end

        local count = drawableCount(ped, def)
        if count <= 0 then return end

        if type(which) == "table" then
            -- lista explícita de drawables (filtrada)
            for _, drawable in ipairs(which) do
                addDrawable(category, def, drawable, count)
            end
        else
            -- true = a categoria inteira
            for drawable = 0, count - 1 do
                addDrawable(category, def, drawable, count)
            end
        end
    end

    -- segue a ordem recomendada, mas só as selecionadas
    for _, category in ipairs(C.ORDER) do
        if selected[category] then
            addCategory(category, selected[category])
        end
    end

    return items
end

Autophoto.register("client.enumerate", enumerate)
return enumerate
