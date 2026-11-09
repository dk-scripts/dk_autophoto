-- ============================================================================
-- Locale loader (client)
--
-- Os arquivos em locales/<idioma>/ já se registraram no namespace. Aqui escolhemos
-- o idioma de config.shared.locale e montamos o acessor `Locale`. Chave que falta
-- no idioma escolhido cai no inglês; se também faltar, devolve a própria chave.
-- ============================================================================

local lang = Autophoto.use("config.shared").locale or "pt-br"

local function pack(language)
    return {
        game = Autophoto.tryUse("locale." .. language .. ".game") or {},
        ui = Autophoto.tryUse("locale." .. language .. ".ui") or {},
        shared = Autophoto.tryUse("locale." .. language .. ".shared") or {},
    }
end

local active = pack(lang)
local fallback = pack("en")

local Locale = {}

--- Gera o acessor de um escopo. `Locale.game("captureDone", 10, 2)` aplica
--- string.format quando há argumentos.
local function make(scope)
    return function(key, ...)
        local value = active[scope][key]
        if value == nil then value = fallback[scope][key] end
        if value == nil then return key end

        if select("#", ...) > 0 and type(value) == "string" then
            local ok, formatted = pcall(string.format, value, ...)
            if ok then return formatted end
        end
        return value
    end
end

Locale.game = make("game")
Locale.ui = make("ui")
Locale.shared = make("shared")

--- Pacote completo de textos da UI, enviado de uma vez à NUI (ui + os nomes das
--- categorias de shared).
function Locale.uiPack()
    local uiTexts = {}
    for key, value in pairs(fallback.ui) do uiTexts[key] = value end
    for key, value in pairs(active.ui) do uiTexts[key] = value end
    uiTexts.categories = active.shared.categories or fallback.shared.categories or {}
    return uiTexts
end

Autophoto.register("Locale", Locale)
return Locale
