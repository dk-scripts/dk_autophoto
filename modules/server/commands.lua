-- ============================================================================
-- Commands: registra o comando que abre a UI (permissão + cooldown no server)
-- ============================================================================

local shared = Autophoto.use("shared")
local serverConfig = Autophoto.use("config.server")
local Locale = Autophoto.use("Locale")
local cooldown = shared.cooldown

local commands = {}

-- Intervalo mínimo entre dois avisos de "sem permissão" no console por jogador, para
-- quem insiste no comando não encher o log.
local DENIAL_LOG_INTERVAL_MS = 10000

--- Valida a permissão de um jogador para abrir o tirador.
---@param src number
---@return boolean
function commands.canUse(src)
    if not serverConfig.permission.enabled then
        return true
    end
    return IsPlayerAceAllowed(src, serverConfig.permission.ace) == true
end

--- Avisa no console, a cada inicialização, que qualquer jogador pode usar o tirador.
local function warnPermissionDisabled()
    print("^3[dk_autophoto] AVISO:^0 a permissão está DESLIGADA (permission.enabled = false em config/server/config.lua).")
    print(("^3[dk_autophoto]^0 Qualquer jogador conectado pode abrir a UI com /%s e gravar arquivos no servidor."):format(
        serverConfig.command.name))
    print(("^3[dk_autophoto]^0 Em servidor aberto, ligue permission.enabled e libere só quem precisa: add_ace identifier.license:XXXX %s allow"):format(
        serverConfig.permission.ace))
end

if not serverConfig.permission.enabled then
    warnPermissionDisabled()
end

--- Mostra uma notificação do jogo ao jogador. Não usa o chat: servidores com chat
--- customizado ou sem chat não exibiriam a mensagem.
local function notify(src, message)
    TriggerClientEvent("dk_autophoto:client:notify", src, message)
end

--- Identificador do jogador, no formato que o `add_ace` do server.cfg aceita.
local function identifierOf(src)
    local license = GetPlayerIdentifierByType and GetPlayerIdentifierByType(src, "license")
    return license or GetPlayerIdentifier(src, 0)
end

--- Explica no console do server por que o jogador foi barrado e o que fazer.
local function logDenial(src)
    if cooldown.check("denial:" .. src, DENIAL_LOG_INTERVAL_MS) then return end

    print(("^3[dk_autophoto]^0 %s (id %d) usou /%s sem permissão. Para liberar, adicione ao server.cfg:"):format(
        GetPlayerName(src) or "?", src, serverConfig.command.name))
    print(("    add_ace %s %s allow"):format(
        "identifier." .. tostring(identifierOf(src)), serverConfig.permission.ace))
    print("^3[dk_autophoto]^0 Ou desligue `permission.enabled` em config/server/config.lua (só em servidor de testes).")
end

RegisterCommand(serverConfig.command.name, function(src)
    src = tonumber(src)
    if not src or src <= 0 then return end -- só de um jogador real, não do console

    if not commands.canUse(src) then
        notify(src, Locale.game("noPermission"))
        logDenial(src)
        return
    end

    if cooldown.check("open:" .. src, serverConfig.cooldownMs) then
        notify(src, Locale.game("onCooldown"))
        return
    end

    TriggerClientEvent("dk_autophoto:client:openUi", src)
end, false)

AddEventHandler("playerDropped", function()
    local src = source
    cooldown.clear("open:" .. src)
    cooldown.clear("denial:" .. src)
end)

Autophoto.register("server.commands", commands)
return commands
