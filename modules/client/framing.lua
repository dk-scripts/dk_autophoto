-- ============================================================================
-- Framing: quadro-guia na tela e cálculo da área recortada (crop)
--
-- O screenshot sai com a tela inteira. Este módulo calcula o quadrado central que
-- vira a foto (a NUI faz o recorte, ver capture.shoot) e desenha esse quadrado
-- na tela enquanto a UI está aberta, para você ver o que vai sair na foto.
-- ============================================================================

local shared = Autophoto.use("shared")
local clientConfig = Autophoto.use("config.client")
local clamp = shared.utils.clamp

local framing = {}

local overlayActive = false

--- Calcula o quadrado central, em fração da tela (0 a 1). O lado é squareSize
--- vezes a menor dimensão; como a tela costuma ser 16:9, o lado em X (fração da
--- largura) é menor que o lado em Y (fração da altura).
---@return table crop { x, y, w, h }: canto superior esquerdo e tamanho, em fração da tela
function framing.computeCrop()
    local size = clamp(clientConfig.framing.squareSize, 0.1, 1.0)

    -- aspecto da tela (largura/altura). GetActiveScreenResolution dá pixels.
    local w, h = GetActiveScreenResolution()
    local aspect = (w > 0 and h > 0) and (w / h) or (16 / 9)

    -- lado do quadrado em fração da ALTURA = size. Em fração da LARGURA, divide
    -- pelo aspecto (porque a largura cobre mais "mundo" por fração).
    local sideY = size
    local sideX = size / aspect

    return {
        x = (1.0 - sideX) / 2.0,
        y = (1.0 - sideY) / 2.0,
        w = sideX,
        h = sideY,
    }
end

--- Liga/desliga o quadro-guia (config.framing.showOverlay ainda vale).
function framing.setOverlay(active)
    overlayActive = active and clientConfig.framing.showOverlay
end

--- Desenha o quadro-guia; deve ser chamada a cada frame enquanto ativo. Escurece a
--- área fora do quadrado e desenha a borda.
---
--- O DrawRect mede x e largura em fração da LARGURA da tela, e y e altura em fração
--- da ALTURA. Por isso a borda vertical usa `thickness / aspect`: sem isso ela
--- ficaria mais grossa que a horizontal.
function framing.draw()
    if not overlayActive then return end

    local crop = framing.computeCrop()
    local dim = clientConfig.framing.dimAlpha
    local cx = crop.x + crop.w / 2.0
    local cy = crop.y + crop.h / 2.0

    local sw, sh = GetActiveScreenResolution()
    local aspect = (sw > 0 and sh > 0) and (sw / sh) or (16 / 9)

    local left, right = crop.x, crop.x + crop.w
    local top, bottom = crop.y, crop.y + crop.h

    if clientConfig.framing.dimOutside then
        -- Faixas escuras: topo e base cobrem a largura toda, e as laterais só a altura
        -- do quadrado, para os cantos não escurecerem duas vezes.
        DrawRect(0.5, top / 2.0, 1.0, top, 0, 0, 0, dim) -- topo
        DrawRect(0.5, (1.0 + bottom) / 2.0, 1.0, 1.0 - bottom, 0, 0, 0, dim) -- base
        DrawRect(left / 2.0, cy, left, crop.h, 0, 0, 0, dim) -- esquerda
        DrawRect((1.0 + right) / 2.0, cy, 1.0 - right, crop.h, 0, 0, 0, dim) -- direita
    end

    -- Borda do quadrado; `thickness` é fração da altura da tela.
    local thickness = 0.0024
    local verticalThickness = thickness / aspect
    local r, g, b = 255, 255, 255
    DrawRect(cx, top, crop.w, thickness, r, g, b, 210) -- topo
    DrawRect(cx, bottom, crop.w, thickness, r, g, b, 210) -- base
    DrawRect(left, cy, verticalThickness, crop.h, r, g, b, 210) -- esquerda
    DrawRect(right, cy, verticalThickness, crop.h, r, g, b, 210) -- direita
end

Autophoto.register("client.framing", framing)
return framing
