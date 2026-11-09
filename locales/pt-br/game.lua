-- Textos in-game (notify, comandos, console) — pt-br
local t = {
    noPermission = "Você não tem permissão para usar o tirador de fotos.",
    onCooldown = "Aguarde um instante antes de tentar novamente.",
    sessionStart = "Sessão de captura iniciada.",
    sessionEnd = "Sessão de captura encerrada.",
    captureDone = "Captura concluída: %d fotos salvas, %d falhas.",
    captureError = "Erro durante a captura: %s",
    screenshotFail = "Falha ao capturar/salvar a foto da peça %s.",
    openCommand = "Abre o tirador automático de fotos de roupas.",
}

Autophoto.register("locale.pt-br.game", t)
return t
