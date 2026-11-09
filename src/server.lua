-- ============================================================================
-- dk_autophoto — entrypoint do SERVER
--
-- Os módulos já foram carregados na ordem do fxmanifest. Este arquivo ativa o
-- orquestrador e avisa no console se nenhum recurso de screenshot estiver
-- iniciado. A lógica fica em modules/server/.
-- ============================================================================

local shared = Autophoto.use("shared")
Autophoto.use("server.init")

CreateThread(function()
    -- Dá tempo para o screenshot-basic iniciar, caso o server.cfg o carregue depois.
    Wait(1000)

    local found
    for _, name in ipairs(shared.config.screenshotResources or { "screenshot-basic" }) do
        if GetResourceState(name) == "started" then
            found = name
            break
        end
    end

    if not found then
        print("^3[dk_autophoto]^0 nenhum recurso de screenshot iniciado (screenshot-basic ou screenshot). Sem ele a captura não funciona: adicione `ensure screenshot-basic` antes do `ensure dk_autophoto` no server.cfg. Se o seu tem outro nome, ajuste `screenshotResources` em config/shared/config.lua.")
    else
        shared.utils.debugPrint("server inicializado; screenshot disponível:", found)
    end
end)
