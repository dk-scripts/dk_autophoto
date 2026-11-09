-- ============================================================================
-- Cooldown: intervalo mínimo entre duas ações da mesma chave
-- ============================================================================

local cooldown = {}

local store = {}

--- Retorna true se a chave ainda está em cooldown; caso contrário registra o
--- novo cooldown e retorna false. Usa GetGameTimer (disponível em client e server).
---@param key string|number
---@param durationMs integer
---@return boolean onCooldown
function cooldown.check(key, durationMs)
    local now = GetGameTimer()
    local until_ = store[key]

    if until_ and now < until_ then
        return true
    end

    store[key] = now + durationMs
    return false
end

--- Limpa o cooldown de uma chave (ex.: ao desconectar um player no server).
function cooldown.clear(key)
    store[key] = nil
end

Autophoto.register("cooldown", cooldown)
return cooldown
