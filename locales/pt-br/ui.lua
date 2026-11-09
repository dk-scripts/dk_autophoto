-- Textos da NUI — pt-br
local t = {
    title = "Auto Foto",
    subtitle = "Tirador automático de fotos de roupas",

    tabCategories = "Categorias",
    tabCamera = "Câmera",
    tabCapture = "Captura",

    selectAll = "Selecionar tudo",
    selectNone = "Limpar seleção",
    components = "Roupas",
    props = "Acessórios",

    markAllInCategory = "Todas",
    clearCategory = "Nenhuma",
    variationsLabel = "Variações",
    selectionHint = "Shift = intervalo · arraste para pintar · Ctrl+A = todas",

    gender = "Modelo",
    male = "Masculino",
    female = "Feminino",

    fov = "Zoom (FOV)",
    distance = "Distância",
    height = "Altura",
    pitch = "Inclinação",
    angle = "Ângulo",
    heightOffset = "Ajuste V",
    sideOffset = "Ajuste L",
    squareSize = "Tamanho do quadro",
    reposition = "Reposicionar câmera",
    repositionHint = "Use as setas para girar/altura e o scroll para zoom. Enter confirma, Backspace cancela.",
    resetCamera = "Restaurar câmera",

    -- modo da câmera (automática por peça x fixa) + perfis por categoria
    cameraMode = "Modo da câmera",
    cameraAuto = "Automática",
    cameraFixed = "Fixa",
    activeCategory = "Peça em foco",
    saveCategoryProfile = "Salvar para esta peça",
    profileSaved = "Perfil salvo para esta peça.",

    -- "Prender câmera": dropdown de partes do corpo (keys de lockTargets na config)
    lockCamera = "Prender câmera",
    lockFree = "Livre (manual)",
    lockHead = "Cabeça",
    lockNeck = "Pescoço",
    lockChest = "Peito",
    lockWaist = "Cintura",
    lockLegs = "Pernas",
    lockFeet = "Pés",
    lockFull = "Corpo inteiro",

    texturesLabel = "Texturas por peça",
    texFirst = "Apenas a primeira",
    texAll = "Todas",

    start = "Iniciar captura",
    pause = "Pausar",
    resume = "Retomar",
    stop = "Parar",
    retryFailed = "Repetir falhas",

    saved = "Salvas",
    failed = "Falhas",
    remaining = "Restantes",
    eta = "Tempo estimado",

    statusIdle = "Pronto",
    statusRunning = "Capturando…",
    statusPaused = "Pausado",
    statusDone = "Concluído",
    statusError = "Erro",

    close = "Fechar",
    noSelection = "Selecione ao menos uma categoria.",
}

Autophoto.register("locale.pt-br.ui", t)
return t
