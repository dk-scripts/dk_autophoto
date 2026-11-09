-- ============================================================================
-- Constantes: mapa de categorias -> slot do jogo (component ou prop)
--
-- O GTA V separa as peças em COMPONENTS (SetPedComponentVariation) e PROPS
-- (SetPedPropIndex), com índices de slot próprios e APIs de enumeração distintas.
-- Cada categoria aqui sabe seu tipo e seu índice de slot.
-- ============================================================================

local C = {}

-- isProp=false -> usa SetPedComponentVariation / GetNumberOfPedDrawableVariations
-- isProp=true  -> usa SetPedPropIndex / GetNumberOfPedPropDrawableVariations
--
-- Component slots (GTA V):
--   1 mask, 3 arms/upper, 4 pants/legs, 5 backpack, 6 shoes,
--   7 accessory(chains), 8 undershirt, 9 vest/armor, 10 decals, 11 torso/jacket
-- Prop slots:
--   0 hat, 1 glasses, 2 ear, 6 watch, 7 bracelet
--
-- As chaves daqui nomeiam a pasta de cada categoria (o {part} de output.path), por
-- exemplo output/<modelo>/<categoria>/. Uma loja que monta a URL da foto pela
-- categoria precisa usar os mesmos nomes. Estes são os do dk_skinshop, por isso
-- é "backpack" e não "bag".
C.CATEGORIES = {
    -- components
    mask = { isProp = false, slot = 1 },
    arms = { isProp = false, slot = 3 },
    pants = { isProp = false, slot = 4 },
    backpack = { isProp = false, slot = 5 },
    shoes = { isProp = false, slot = 6 },
    accessory = { isProp = false, slot = 7 }, -- correntes/colares
    tshirt = { isProp = false, slot = 8 }, -- undershirt
    vest = { isProp = false, slot = 9 }, -- body armor / vest
    decals = { isProp = false, slot = 10 },
    torso = { isProp = false, slot = 11 }, -- jaqueta / torso principal

    -- props
    hat = { isProp = true, slot = 0 },
    glass = { isProp = true, slot = 1 },
    ear = { isProp = true, slot = 2 },
    watch = { isProp = true, slot = 6 },
    bracelet = { isProp = true, slot = 7 },
}

-- Ordem de captura recomendada (peças de baixo primeiro evita oclusão estranha).
C.ORDER = {
    "torso", "vest", "tshirt", "arms", "accessory", "decals",
    "pants", "shoes", "backpack", "mask",
    "hat", "glass", "ear", "watch", "bracelet",
}

C.STATUS = {
    IDLE = "idle",
    RUNNING = "running",
    PAUSED = "paused",
    DONE = "done",
    ERROR = "error",
}

Autophoto.register("constants", C)
return C
