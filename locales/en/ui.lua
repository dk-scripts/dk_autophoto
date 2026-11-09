-- NUI texts — en
local t = {
    title = "Auto Photo",
    subtitle = "Automatic clothing photo tool",

    tabCategories = "Categories",
    tabCamera = "Camera",
    tabCapture = "Capture",

    selectAll = "Select all",
    selectNone = "Clear selection",
    components = "Clothing",
    props = "Accessories",

    markAllInCategory = "All",
    clearCategory = "None",
    variationsLabel = "Variations",
    selectionHint = "Shift = range · drag to paint · Ctrl+A = all",

    gender = "Model",
    male = "Male",
    female = "Female",

    fov = "Zoom (FOV)",
    distance = "Distance",
    height = "Height",
    pitch = "Pitch",
    angle = "Angle",
    heightOffset = "V offset",
    sideOffset = "Side offset",
    squareSize = "Frame size",
    reposition = "Reposition camera",
    repositionHint = "Use arrows to rotate/height and scroll to zoom. Enter confirms, Backspace cancels.",
    resetCamera = "Reset camera",

    -- camera mode (auto per piece vs fixed) + per-category profiles
    cameraMode = "Camera mode",
    cameraAuto = "Automatic",
    cameraFixed = "Fixed",
    activeCategory = "Piece in focus",
    saveCategoryProfile = "Save for this piece",
    profileSaved = "Profile saved for this piece.",

    -- "Lock camera": body-part dropdown (lockTargets keys in the config)
    lockCamera = "Lock camera",
    lockFree = "Free (manual)",
    lockHead = "Head",
    lockNeck = "Neck",
    lockChest = "Chest",
    lockWaist = "Waist",
    lockLegs = "Legs",
    lockFeet = "Feet",
    lockFull = "Full body",

    texturesLabel = "Textures per piece",
    texFirst = "First only",
    texAll = "All",

    start = "Start capture",
    pause = "Pause",
    resume = "Resume",
    stop = "Stop",
    retryFailed = "Retry failed",

    saved = "Saved",
    failed = "Failed",
    remaining = "Remaining",
    eta = "ETA",

    statusIdle = "Ready",
    statusRunning = "Capturing…",
    statusPaused = "Paused",
    statusDone = "Done",
    statusError = "Error",

    close = "Close",
    noSelection = "Select at least one category.",
}

Autophoto.register("locale.en.ui", t)
return t
