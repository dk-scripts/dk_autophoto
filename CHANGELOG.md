# Changelog

Todas as mudanças notáveis deste projeto são documentadas aqui.
O formato segue [Keep a Changelog](https://keepachangelog.com/) e o projeto adota
[Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [2.0.0] - 2026-11-09

Primeira versão publicada no GitHub. Quem usava as versões 1.x deve ler a seção
"Alterado", que lista as quebras de contrato: formato do `index.json`, retorno do
`getPhoto`, nome da categoria `bag` e o idioma em outro arquivo de config.

### Adicionado
- Aviso no console, a cada inicialização, quando `permission.enabled = false` (o padrão):
  qualquer jogador conectado pode abrir a UI e gravar arquivos no servidor, e o aviso mostra
  como ligar a permissão. O README tem o mesmo aviso no topo e na seção Permissão.
- Aviso de falta de permissão como notificação do jogo, no lugar da mensagem de chat, que
  não aparecia em servidores sem chat ou com chat customizado. O console do server mostra
  a linha `add_ace` que libera aquele jogador.
- Seleção de variações por categoria: cada categoria abre uma grade com uma célula por
  drawable, para fotografar só as peças escolhidas. Atalhos: Shift (intervalo), arrastar
  (pintar) e Ctrl+A (todas). Categoria marcada sem abrir a grade continua fotografando
  todas as peças.
- Dois presets de roupa base (`config.client.ped.baseOutfit.preview` e `.capture`): o
  `preview` (torso visível) é aplicado ao abrir a UI, para enquadrar a câmera, e o
  `capture` (torso invisível) é aplicado ao clicar em "Iniciar captura". A fila volta
  para `preview` ao pausar, parar ou concluir.
- Nova categoria `accessory` (component 7, correntes e colares).
- `config.shared.locale` define o idioma da UI e das mensagens do jogo, tanto no client
  quanto no server.
- O hook de server `onError` agora é chamado quando uma foto falha ao salvar.

### Alterado
- **O `path` de cada foto agora é relativo à pasta de saída** (`mp_m_freemode_01/torso/4_0.webp`),
  em vez de um caminho `nui://`. Um caminho `nui://` só resolve se as fotos forem enviadas
  ao client pelo `files {}`, o que faria cada jogador baixar milhares de arquivos ao
  conectar. Sirva a pasta `output/` por HTTP (veja o README). Isso vale para o
  `index.json`, para o export `getPhoto` e para o segundo argumento do hook `onShot`.
- **O `index.json` agora é indexado por modelo** (`photos[modelo][categoria][drawable][textura]`).
  Antes, a foto masculina e a feminina da mesma peça se sobrescreviam no índice, e o
  `getPhoto` devolvia a última que foi fotografada. O export ganhou o argumento opcional
  `model` (padrão `mp_m_freemode_01`): `getPhoto(category, drawable, texture, model)`.
  Um `index.json` gerado por versões anteriores deve ser apagado: ele é recriado conforme
  você fotografa.
- A categoria `bag` foi renomeada para `backpack` (mesmo slot 5), alinhando os nomes
  com o `dk_skinshop`. Fotos já geradas em `output/<modelo>/bag/` continuam no disco com o
  nome antigo: renomeie a pasta para `backpack` ou refaça as fotos dessa categoria.
- O `fxmanifest.lua` não declara mais `output/index.json` em `files {}`. Num download limpo
  o arquivo ainda não existe, e as fotos não devem ser enviadas aos jogadores. A pasta
  `output/` continua vindo no repositório.
- Câmera manual alcança os pés: `limits.height` passou de `0.0..1.2` para `-0.6..1.2` e
  `limits.pitch` de `±25` para `±45`. Os sliders da UI seguem os novos limites.
- O idioma deixou de ficar em `config.client.locale` e passou para `config.shared.locale`.
  O server antes sempre usava pt-br.
- Removido `config.shared.naming`: ele só nomeava a chave interna da fila e dava a impressão
  de controlar o nome dos arquivos, que vem de `config.server.output.path`.
- Comentários, README e CONTRIBUTING reescritos para quem usa e contribui com o recurso.

### Corrigido
- Fechar a UI (botão ou ESC) deixava a câmera de captura ativa e o ped spawnado. Agora a
  câmera volta ao jogador e o ped é removido, e uma captura em andamento não recria o ped
  depois disso.
- O enquadramento da calça cortava a metade de baixo da perna. O perfil agora mira a
  cintura, com a câmera inclinada para baixo e mais afastada.
- O `saveShot` aceitava um `model` com `..`, que fazia a foto sair da pasta de saída.
  Agora o modelo e o gênero são validados no server, e pontos são removidos de todo valor
  que entra no caminho.
- O evento `captureComplete` não conferia a permissão e podia ser disparado por qualquer
  jogador.

## [1.1.0] - 2026-06-25

### Adicionado
- Câmera automática por peça: cada categoria tem um perfil de câmera próprio
  (`config.camera.autoProfiles`) que mira a parte certa do corpo (peito, pernas,
  pés...) e ajusta FOV e distância. A câmera muda sozinha entre as peças durante a
  captura. Na aba Câmera, o botão "Modo da câmera: Automática | Fixa" alterna entre o
  perfil por peça e uma câmera única; em automático há o seletor "Peça em foco" (preview
  ao vivo) e "Salvar para esta peça" (ajuste guardado na sessão). Novas chaves de config:
  `camera.defaultMode` e `camera.cameraSettleMs`.
- "Prender câmera": lista na aba Câmera para travar a câmera numa parte do corpo do ped
  (cabeça, pescoço, peito, cintura, pernas, pés, corpo inteiro ou livre). A câmera mira o
  osso escolhido continuamente, reajustando ao trocar de ped ou de roupa. As partes são
  configuráveis em `config.camera.lockTargets` e `defaultLock`.

### Corrigido
- A roupa base (`baseOutfit`) do ped agora é resolvida por modelo: os índices
  "mínimo/invisível" diferem entre `mp_m_freemode_01`, `mp_f_freemode_01` e addons.
  Estrutura nova: `baseOutfit.default` (fallback) e `baseOutfit.byModel[<modelo>]`. Antes,
  um único conjunto de índices valia para todos os modelos, e peças vazavam no fundo da foto
  do ped feminino e dos addons.
- Zoom distorcido ao ajustar a câmera pela UI: os nativos de câmera exigem `float`, e os
  inteiros vindos da NUI (JSON) agora são normalizados.

## [1.0.0] - 2026-06-22

### Adicionado
- Captura automática de fotos por peça (`categoria`, `drawable` e `textura`) com um ped
  dedicado e o `screenshot-basic`.
- Enumeração automática do catálogo do jogo (components e props).
- Fotos recortadas em quadrado e salvas em `webp`.
- UI em HTML, CSS e JS puro, com quadro-guia de preview.
- Reposicionamento de câmera ao vivo (girar, altura, zoom, inclinação, FOV).
- Fila com pausar, retomar, parar e repetir falhas.
- Geração do `output/index.json` e exports `getPhoto`, `getManifest` e `isReady`.
- Hooks de client e server (`onBeforeShot`, `onShot`, `onProgress`, `onComplete`, `onError`,
  `onSessionStart`).
- Locales pt-br e en. Tema da UI configurável em `config.ui.theme`.
- Permissão opcional por ACE, cooldown e logs no server com webhook.
