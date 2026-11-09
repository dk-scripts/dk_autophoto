-- ============================================================================
-- dk_autophoto — entrypoint do CLIENT
--
-- Os módulos já foram carregados na ordem do fxmanifest. Este arquivo só confirma
-- que o client subiu e expõe o export `openUi`. A lógica fica em modules/client/.
-- ============================================================================

local shared = Autophoto.use("shared")
local client = Autophoto.use("client.init")

shared.utils.debugPrint("client inicializado")

-- Abre a UI sem passar pelo comando, para outro script client-side (um menu de
-- admin, por exemplo). Este caminho NÃO checa permissão: quem protege a gravação
-- é o server, que confere a permissão a cada foto salva.
exports("openUi", function()
    client.openUi()
end)
