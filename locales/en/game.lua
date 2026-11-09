-- In-game texts (notify, commands, console) — en
local t = {
    noPermission = "You don't have permission to use the photo tool.",
    onCooldown = "Please wait a moment before trying again.",
    sessionStart = "Capture session started.",
    sessionEnd = "Capture session ended.",
    captureDone = "Capture finished: %d photos saved, %d failed.",
    captureError = "Error during capture: %s",
    screenshotFail = "Failed to capture/save the photo for piece %s.",
    openCommand = "Opens the automatic clothing photo tool.",
}

Autophoto.register("locale.en.game", t)
return t
