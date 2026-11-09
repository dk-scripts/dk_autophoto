-- ============================================================================
-- Orquestrador do contexto shared
--
-- Os módulos shared já se registraram no namespace Autophoto pela ordem do
-- manifest. Este init apenas expõe um agregador conveniente e valida que tudo
-- carregou — falhar aqui dá um erro claro em vez de um nil silencioso adiante.
-- ============================================================================

local shared = {
    config = Autophoto.use("config.shared"),
    constants = Autophoto.use("constants"),
    utils = Autophoto.use("utils"),
    cooldown = Autophoto.use("cooldown"),
}

Autophoto.register("shared", shared)
return shared
