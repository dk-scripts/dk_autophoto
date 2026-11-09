-- ============================================================================
-- Loader de módulos
--
-- Cada módulo se registra no namespace global `Autophoto` com
-- `Autophoto.register("nome", tabela)`, e quem precisa dele usa
-- `Autophoto.use("nome")`. O fxmanifest carrega os arquivos na ordem certa, então
-- um módulo só pode usar os que vêm antes dele na lista.
--
-- Escolhemos esse registro em vez do `require` do FiveM porque o `require` nativo
-- se comporta de forma diferente entre versões de artifacts, e assim o recurso
-- funciona sem depender de nenhum outro. `Autophoto` é a única global do recurso.
-- ============================================================================

Autophoto = Autophoto or {}

local registry = {}

--- Registra um módulo no namespace. Registrar o mesmo nome de novo sobrescreve.
---@param name string
---@param value any
---@return any value
function Autophoto.register(name, value)
    registry[name] = value
    return value
end

--- Devolve um módulo já registrado. Se faltar, falha com uma mensagem apontando
--- para a ordem do fxmanifest.
---@param name string
---@return any
function Autophoto.use(name)
    local value = registry[name]

    if value == nil then
        error(("[dk_autophoto] módulo '%s' não registrado — confira a ordem em fxmanifest.lua"):format(tostring(name)), 2)
    end

    return value
end

--- Como `use`, mas devolve nil em vez de falhar. Serve para módulos opcionais.
---@param name string
---@return any|nil
function Autophoto.tryUse(name)
    return registry[name]
end
