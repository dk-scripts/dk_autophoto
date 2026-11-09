# Contribuindo com o dk_autophoto

Obrigado por querer contribuir! Este guia explica como rodar o recurso localmente e o que
esperamos de um pull request.

## Rodando localmente

1. Tenha o `screenshot-basic` instalado e iniciado.
2. Coloque `ensure screenshot-basic` e `ensure dk_autophoto` no `server.cfg`, nessa ordem.
3. Ative o debug para ver os logs: em `config/shared/config.lua`, `debug.enabled = true`.
4. A permissão vem desligada por padrão, então basta usar `/autophoto` (o console avisa isso).
   Para testar o fluxo com permissão, ligue `permission.enabled` em `config/server/config.lua`
   e dê o ACE `command.dk_autophoto` ao seu usuário.

Não há build: a UI é HTML, CSS e JS puro em `web/`. Edite e rode `restart dk_autophoto`.

## Padrão de código

- **Standalone**: sem framework e sem biblioteca de terceiros. A única dependência é o
  `screenshot-basic`.
- Lua 5.4. `local` por padrão, `camelCase` em variáveis e funções, `UPPER_CASE` em
  constantes, e `PascalCase` só para a global `Autophoto`.
- Cada módulo retorna uma tabela e se registra com `Autophoto.register("nome", tabela)`.
  Quem precisa dele usa `Autophoto.use("nome")`. A ordem de carregamento é a do
  `fxmanifest.lua` (veja `modules/shared/loader.lua`).
- O contexto vem da pasta (`modules/client/`, `modules/server/`, `modules/shared/`), não do
  nome do arquivo.
- O server é a autoridade. Os eventos são públicos, então cada um confere a permissão e
  valida o payload antes de gravar qualquer coisa. Callbacks da NUI sempre chamam `cb`.
- Eventos de rede seguem `dk_autophoto:contexto:ação` (`dk_autophoto:server:saveShot`).
- Hooks do usuário rodam sob `pcall`.
- Sem `TriggerClientEvent(evento, -1, ...)`.
- Comentários explicam o porquê de uma decisão, não o que o código já diz.
- Indentação de 4 espaços, aspas duplas, e sem alinhar valores em colunas.

## Estrutura

```
src/        pontos de entrada enxutos (client.lua e server.lua)
modules/    lógica, separada em client, server e shared
config/     valores editáveis, separados em client, server e shared
locales/    pt-br e en (game, ui e shared)
web/        interface (HTML, CSS e JS puro)
output/     fotos e index.json gerados no jogo (ignorados pelo git)
```

A pasta `output/` vem no repositório só com o `.gitkeep`. Nunca inclua fotos geradas em um
commit.

## Pull requests

- Descreva o que mudou e por quê.
- Mantenha o estilo e a separação por contexto.
- Atualize o `CHANGELOG.md` e os dois idiomas em `locales/` (pt-br e en) quando aplicável.
- Se mexer num export, num hook ou no formato do `index.json`, atualize o README: eles são o
  contrato público do recurso.
- Teste no jogo antes de abrir o PR: captura, pausar e retomar, reposicionar a câmera e os
  dois modelos de ped.

## Issues

Inclua a versão dos artifacts do FiveM, a versão do `screenshot-basic`, os passos para
reproduzir e o log do console com `debug.enabled = true`.
