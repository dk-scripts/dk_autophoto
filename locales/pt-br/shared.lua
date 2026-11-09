-- Textos usados em jogo e na UI — pt-br
local t = {
    enabled = "Ativado",
    disabled = "Desativado",
    loading = "Carregando…",
    yes = "Sim",
    no = "Não",

    -- nomes amigáveis das categorias (também usados pela UI)
    categories = {
        torso = "Jaqueta",
        vest = "Colete",
        tshirt = "Camiseta",
        arms = "Mãos",
        decals = "Estampas",
        accessory = "Acessório",
        pants = "Calças",
        shoes = "Sapatos",
        backpack = "Mochila",
        mask = "Máscara",
        hat = "Chapéu",
        glass = "Óculos",
        ear = "Brincos",
        watch = "Relógio",
        bracelet = "Pulseira",
    },
}

Autophoto.register("locale.pt-br.shared", t)
return t
