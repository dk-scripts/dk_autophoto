# dk_autophoto

Tirador automático de fotos de roupas para FiveM. Ele veste um ped numa sala isolada e
gera uma foto quadrada (`.webp`) de cada peça (categoria, drawable e textura), pronta para
alimentar uma loja de roupas, como o `dk_skinshop`.

Open source, standalone, sob licença MIT. Feito pela DK Development.

> **Aviso de segurança:** a permissão vem **desligada** por padrão (`permission.enabled = false`).
> Enquanto estiver assim, qualquer jogador conectado pode abrir a UI e gravar arquivos no
> servidor, e o console avisa isso a cada inicialização. Em servidor aberto, ligue a permissão
> antes de usar. Veja [Permissão](#permissão).

## Recursos

- Veste um ped dedicado, masculino ou feminino, num local isolado e fotografa cada peça
  sozinho.
- Lê o catálogo direto do jogo: você não informa quantos drawables ou texturas existem, e
  peças de pacotes addon entram na fila automaticamente.
- 15 categorias: máscara, braços, camiseta, colete, jaqueta, estampas, acessório
  (correntes e colares), mochila, calças e sapatos, mais os props chapéu, óculos, brincos,
  relógio e pulseira.
- Escolha das peças por categoria: marque a categoria inteira ou abra a grade de variações
  e selecione só as que quiser (Shift para intervalo, arrastar para pintar, Ctrl+A para
  todas).
- Câmera automática por peça (cada categoria tem o seu enquadramento) ou câmera fixa. A
  câmera pode ficar presa a uma parte do corpo e ser ajustada ao vivo.
- Quadro-guia na tela mostrando exatamente a área que vira a foto. O arquivo sai recortado
  em quadrado (512 x 512 por padrão).
- Fila com pausar, retomar, parar e repetir falhas.
- Gera um `output/index.json` com todas as fotos e exports para outros scripts consultarem.
- Sem ofuscação e sem framework: só precisa do `screenshot-basic`.

## Requisitos

| Recurso | Obrigatório | Para quê |
|---|---|---|
| [`screenshot-basic`](https://github.com/citizenfx/screenshot-basic) | Sim | capturar a tela do operador |

O `screenshot-basic` precisa estar buildado (com a pasta `dist/`). O nome da pasta varia
entre servidores, então o `dk_autophoto` procura `screenshot-basic` e depois `screenshot`.
Se o seu tiver outro nome, acrescente em `config/shared/config.lua`:

```lua
screenshotResources = { "screenshot-basic", "screenshot", "meu-screenshot" },
```

## Instalação

1. Coloque a pasta `dk_autophoto` em `resources/` (por exemplo `resources/[dk]/`).
2. No `server.cfg`, inicie o screenshot **antes** do `dk_autophoto`:
   ```cfg
   ensure screenshot-basic
   ensure dk_autophoto
   ```
3. **Em servidor aberto, ligue a permissão.** Por padrão ela vem desligada, e qualquer jogador
   conectado pode abrir a UI e gravar arquivos no servidor (o console avisa isso a cada
   inicialização). Veja [Permissão](#permissão) para ligar e liberar quem vai usar.
4. Entre no jogo e use `/autophoto`.

Não é preciso criar pastas nem arquivos: a pasta `output/` já vem no download, e o
`index.json` e as subpastas de cada modelo e categoria são criados na primeira foto.

## Como usar

1. `/autophoto` abre o painel e leva a câmera para o ped.
2. Aba **Categorias**: marque as categorias que quer fotografar. Clique no nome de uma
   categoria para abrir a grade de variações e escolher só algumas peças.
3. Aba **Câmera**:
   - **Modo da câmera**: *Automática* usa o enquadramento de cada categoria; *Fixa* usa uma
     câmera só para tudo.
   - No modo automático, **Peça em foco** mostra ao vivo o enquadramento de cada categoria, e
     **Salvar para esta peça** guarda o seu ajuste até o recurso reiniciar.
   - Escolha o modelo (masculino ou feminino), a parte do corpo em que a câmera fica presa,
     e ajuste zoom, distância, altura, inclinação, ângulo e o tamanho do quadro.
   - **Reposicionar câmera** libera o ajuste pelo teclado: setas giram e mudam a altura, o
     scroll dá zoom, Enter confirma e Backspace cancela.
   - **Texturas por peça**: só a primeira (uma foto por peça) ou todas.
4. Aba **Captura**: clique em **Iniciar captura** e acompanhe o progresso, as fotos salvas,
   as falhas e o tempo estimado. Dá para pausar, retomar, parar e repetir só as que falharam.

## Onde ficam as fotos e como usá-las na loja

As fotos são salvas em `dk_autophoto/output/`, seguindo o caminho definido em
`config/server/config.lua` (`output.path`). O padrão gera:

```
output/<modelo>/<categoria>/<drawable>_<textura>.webp
output/mp_m_freemode_01/torso/4_0.webp
```

O recurso **não envia as fotos aos jogadores**. Elas ficam de fora do `files {}` do
manifest de propósito: seriam milhares de arquivos baixados por todo mundo que conecta.
Para exibi-las na loja, sirva a pasta `output/` por HTTP, com nginx ou Apache, e aponte a
loja para essa URL.

Exemplo com nginx:

```nginx
location /clothes/ {
    alias /caminho/do/servidor/resources/[dk]/dk_autophoto/output/;
}
```

Aponte para a pasta `output/`, nunca para a raiz do recurso: o `config/server/config.lua`
pode guardar o webhook dos logs.

### dk_skinshop

No `config/shared/config.lua` do `dk_skinshop`, aponte `itemImages.baseUrl` para a URL
acima (sem barra no final):

```lua
itemImages = {
    enabled = true,
    baseUrl = "https://seu-dominio.com/clothes",
}
```

O `pathTemplate` padrão do `dk_skinshop` (`{model}/{category}/{drawable}_{texture}.{ext}`)
já bate com o `output.path` padrão deste recurso, e os nomes das categorias também.

### Outras lojas

Se a sua loja espera outra estrutura de pastas, ajuste `output.path` **antes** de
fotografar (veja [Organização do output](#organização-do-output)). Também dá para montar
a URL de cada foto com o export `getPhoto`.

## Configuração

Tudo fica em `config/`, separado por contexto:

| Arquivo | O que controla |
|---|---|
| `config/shared/config.lua` | idioma, debug, nome do recurso de screenshot, formato e tamanho da foto, texturas e categorias marcadas ao abrir |
| `config/client/config.lua` | ped dedicado e local, roupa base, pose, câmera, quadro-guia, tempos, teclas, tema da UI e hooks do client |
| `config/server/config.lua` | pasta e caminho das fotos, permissão, comando, cooldown, logs e hooks do server |

### Idioma

```lua
-- config/shared/config.lua
locale = "pt-br", -- ou "en"
```

### Texturas

```lua
-- config/shared/config.lua
textures = "first",        -- uma foto por peça (textura 0). Padrão e mais rápido
-- textures = "all",       -- todas as cores de cada peça (muito mais fotos e tempo)
-- textures = { max = 4 }, -- texturas 0 a 3
```

### Organização do output

O caminho de cada foto é um template em `config/server/config.lua`, em `output.path`. Ele
pode ter subpastas, criadas automaticamente:

```lua
output = {
    dir = "output",
    path = "{sex}/{part}/{variation}_{color}.{ext}", -- mp_m_freemode_01/backpack/0_0.webp
},
```

| Padrão | Valor |
|---|---|
| `{sex}` | modelo do ped (`mp_m_freemode_01`) |
| `{gender}` | `male` ou `female` |
| `{part}` | categoria da peça (`torso`, `pants`, `hat`...) |
| `{slot}` | slot do component ou prop no jogo |
| `{variation}` | índice da peça (drawable) |
| `{color}` | índice da textura |
| `{ext}` | extensão (`webp`, `png` ou `jpg`) |

Exemplos: `"{gender}/{part}/{variation}.{ext}"` gera `male/torso/4.webp`, e
`"{part}_{variation}_{color}.{ext}"` gera `torso_4_0.webp`, sem subpastas.

Fotos já salvas não são movidas quando você muda o template.

### Câmera automática por peça

Em `config/client/config.lua`, dentro de `camera`:

- `defaultMode`: `"auto"` (cada categoria usa o seu enquadramento) ou `"fixed"` (uma câmera
  só, definida pelos valores base de `camera`). Dá para alternar na UI.
- `cameraSettleMs`: tempo extra para a câmera assentar depois de trocar de perfil, antes do
  screenshot.
- `autoProfiles`: um perfil por categoria. Cada perfil só precisa dos campos que mudam em
  relação à base (`fov`, `distance`, `height`, `pitch`, `sideAngle`, `heightOffset`,
  `sideOffset`, `lock`). O resto é herdado. A chave `default` vale para categorias sem
  perfil próprio, e `turnPedAround = true` gira o ped de costas, como na mochila.

```lua
autoProfiles = {
    default = { lock = "full" },
    tshirt = { lock = "chest", fov = 50.0, distance = 1.50, sideAngle = 30.0 },
    shoes = { lock = "feet", fov = 40.0, distance = 1.40, sideAngle = 70.0 },
}
```

Os valores padrão foram calibrados nos peds padrão do GTA Online. Com outro mapa ou outro
ped, ajuste pela UI e copie os números para o config.

### Peds addon e roupa base

O ped é vestido com uma roupa base "vazia" antes de cada foto, para a peça anterior não
aparecer no fundo. Os índices dessa roupa mudam de um modelo para outro. Para fotografar um
ped addon, troque o nome em `ped.models` e adicione o modelo em `ped.baseOutfit.preview` e
`ped.baseOutfit.capture`, dentro de `byModel`. Modelos que não estão listados usam `default`.

### Local do ped

`ped.coords` define onde o ped aparece. Escolha um lugar isolado, com o chão carregado. Um
interior ou um mapa de fundo liso dá as melhores fotos.

### Permissão

A permissão vem **desligada** por padrão, para o recurso funcionar logo depois de instalado.
Enquanto estiver desligada, **qualquer jogador conectado** pode abrir a UI com `/autophoto` e
gravar arquivos na pasta do recurso. O console do servidor mostra este aviso a cada
inicialização:

```
[dk_autophoto] AVISO: a permissão está DESLIGADA (permission.enabled = false em config/server/config.lua).
[dk_autophoto] Qualquer jogador conectado pode abrir a UI com /autophoto e gravar arquivos no servidor.
[dk_autophoto] Em servidor aberto, ligue permission.enabled e libere só quem precisa: add_ace identifier.license:XXXX command.dk_autophoto allow
```

Em servidor aberto, ligue a permissão em `config/server/config.lua`:

```lua
permission = {
    enabled = true,
    ace = "command.dk_autophoto",
},
```

E libere só quem precisa, no `server.cfg`:

```cfg
add_ace identifier.license:SEU_LICENSE command.dk_autophoto allow
add_ace group.fotografos command.dk_autophoto allow
```

Quem já tem o ACE `command` liberado (o grupo `admin` do txAdmin, por exemplo) passa direto.
Com a permissão ligada, quem não tem acesso recebe uma notificação no jogo, e o console
mostra a linha `add_ace` que libera aquele jogador.

## Exports

### Server

```lua
-- Caminho da foto, relativo à pasta output, ou nil se não existir.
-- O modelo é opcional e o padrão é mp_m_freemode_01.
local path = exports.dk_autophoto:getPhoto("torso", 4, 0, "mp_f_freemode_01")
--> "mp_f_freemode_01/torso/4_0.webp"

-- O index.json inteiro, como tabela.
local manifest = exports.dk_autophoto:getManifest()

-- Existe um recurso de screenshot iniciado?
local ready = exports.dk_autophoto:isReady()
```

O `index.json` tem os níveis modelo, categoria, drawable e textura. O `crop` cobre sempre a
imagem inteira, porque a foto já sai recortada em quadrado.

```json
{
  "resource": "dk_autophoto",
  "generatedAt": 1718999999,
  "photos": {
    "mp_m_freemode_01": {
      "torso": {
        "4": {
          "0": {
            "path": "mp_m_freemode_01/torso/4_0.webp",
            "crop": { "x": 0, "y": 0, "w": 1, "h": 1 }
          }
        }
      }
    }
  }
}
```

### Client

```lua
-- Abre a UI sem passar pelo comando. Com a permissão ligada, ela continua sendo conferida
-- no server a cada foto salva.
exports.dk_autophoto:openUi()
```

## Hooks

Ficam em `config/client/config.lua` e `config/server/config.lua`. Rodam sob `pcall`: um erro
no seu hook nunca derruba o recurso.

**Client**

```lua
hooks = {
    onBeforeShot = function(item) return true end, -- retorne false para pular esta foto
    onShot = function(item, path) end,             -- path: caminho da foto salva
    onProgress = function(progress) end,
    onComplete = function(stats) end,              -- { total, saved, failed }
    onError = function(item, err) end,
},
```

`item` tem `category`, `slot`, `isProp`, `drawable` e `texture`.

**Server**

```lua
hooks = {
    onSessionStart = function(playerId) end,
    onComplete = function(playerId, stats) end, -- { total, saved, failed }
    onError = function(playerId, err) end,      -- falha ao salvar uma foto
},
```

## Solução de problemas

- **"nenhum recurso de screenshot iniciado" no console.** Adicione `ensure screenshot-basic`
  antes do `ensure dk_autophoto` no `server.cfg` e confirme que ele está buildado. Se a pasta
  tem outro nome, acrescente em `screenshotResources`.
- **A UI não abre ao usar `/autophoto`.** O que aparece no jogo e no console do servidor
  mostra a causa:
  - Notificação "Você não tem permissão..." (só aparece com `permission.enabled = true`): o
    seu usuário não tem o ACE. O console do servidor imprime a linha exata para o
    `server.cfg`, com o seu identificador:
    ```cfg
    add_ace identifier.license:SEU_LICENSE command.dk_autophoto allow
    ```
    Reinicie o servidor, ou execute essa mesma linha no console do servidor, e tente de novo.
    Se o ACE `command` já está liberado para o seu grupo, confira se o seu usuário está
    nesse grupo (`add_principal`).
  - Nenhuma notificação: o recurso não está rodando. Execute `refresh` e `ensure dk_autophoto`
    no console do servidor e procure por erros com `[dk_autophoto]`. Depois de mover ou
    renomear a pasta do recurso, o `refresh` é obrigatório.
- **As fotos não aparecem em `output/`.** Veja o console do servidor: o erro exato é
  impresso (`falha ao salvar`, `decode vazio`). Confirme que o screenshot está iniciado e que
  o servidor tem permissão de escrita na pasta do recurso.
- **"não consegui criar as subpastas".** O host bloqueou a criação de pastas, e as fotos
  foram salvas direto em `output/`, com `_` no lugar das barras. Crie as pastas
  (`output/mp_m_freemode_01/torso/` e assim por diante) ou use um `output.path` sem
  subpastas, como `"{part}_{variation}_{color}.{ext}"`.
- **A foto sai cortada ou torta.** Ajuste zoom, distância e altura na aba Câmera, e o tamanho
  do quadro, até o ped ficar centralizado no quadro-guia antes de iniciar.
- **A peça sai incompleta ou com a textura baixa.** Aumente `settleMs` em
  `config/client/config.lua`, para o jogo ter tempo de carregar a textura.
- **Aparece roupa do ped atrás da peça.** Os índices da roupa base não servem ao seu modelo.
  Veja [Peds addon e roupa base](#peds-addon-e-roupa-base).
- **Demora muito.** Mantenha `textures = "first"` e marque só as categorias de que precisa.
  `"all"` multiplica o número de fotos pelas cores de cada peça.

## Contribuindo

Contribuições são bem-vindas. Veja [CONTRIBUTING.md](CONTRIBUTING.md) e o
[CHANGELOG.md](CHANGELOG.md).

## Licença

[MIT](LICENSE) © 2026 DK Development.
