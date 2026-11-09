-- ============================================================================
-- Locale loader (server)
--
-- O server só precisa dos textos de jogo (locales/<idioma>/game.lua). O idioma vem
-- de config.shared.locale, o mesmo do client. Chave que falta cai no inglês.
-- ============================================================================

local lang = Autophoto.use("config.shared").locale or "pt-br"

local active = Autophoto.tryUse("locale." .. lang .. ".game") or {}
local fallback = Autophoto.tryUse("locale.en.game") or {}

local Locale = {}

function Locale.game(key, ...)
    local value = active[key]
    if value == nil then value = fallback[key] end
    if value == nil then return key end

    if select("#", ...) > 0 and type(value) == "string" then
        local ok, formatted = pcall(string.format, value, ...)
        if ok then return formatted end
    end
    return value
end

Autophoto.register("Locale", Locale)
return Locale
