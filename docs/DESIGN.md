# CÂMARA 7 · Documento Técnico

> Nome provisório. O título vive em `data/config/game.json` (`title`) e em
> `project.godot` (`config/name`); trocar nesses dois lugares basta.

## 1. Visão em uma frase

Mineração top-down em pixel art numa zona de exclusão fictícia, onde o inimigo é o
ambiente (radiação, escuridão, profundidade), e o jogador evolui de **minerador com
picareta improvisada** para **dono de uma operação industrial automatizada**.

**Pilares:** (1) mineração com feedback forte; (2) tensão ambiental — decidir quando
voltar; (3) progressão visível (ferramenta, traje, luz, máquinas na base);
(4) tudo orientado a dados.

## 2. Decisão de tecnologia

| Escolha | Motivo |
|---|---|
| **Godot 4.7 + GDScript** | 2D nativo, TileMapLayer, luzes 2D com sombra, partículas, JSON, saves simples, leve, gratuito. Sem motivo técnico para trocar. |
| Renderer **Compatibility** | Roda em qualquer GPU; luzes 2D funcionam. |
| Resolução interna **480×270**, escala inteira | Pixel art nítida (3× = 1440×810, 4× = 1920×1080). |
| Tiles de **16 px** | Padrão do gênero; legibilidade estilo Stardew. |
| **Assets placeholder gerados por script** (`tools/gen_assets.py`) | Nada pago/proprietário; substituir = sobrescrever o PNG/WAV com o mesmo nome. |
| Fonte **VT323** (SIL OFL) | Visual de terminal/CRT, suporta acentos. |

## 3. Arquitetura

Sistemas globais são **autoloads pequenos e desacoplados**. Eles conversam por
**sinais no `EventBus`** e leem conteúdo do **`DataManager`**. Nós de cena
(Player, Rock, máquinas) só exibem/reagem; regras ficam nos sistemas.

```
           data/*.json ──► DataManager ──► (consultas por id)
                                 │
 EventBus (sinais) ◄────────────┼───────────────────────────────┐
   ▲      ▲      ▲               │                               │
   │      │      │      ┌────────┴─────────┐                     │
Player  Rock   UI ◄──── │ Sistemas (estado) │ ──► SaveSystem (save_version + migrações)
(cena)  (cena) (cena)   │ Inventory Economy │
                        │ Upgrade Radiation │
                        │ Health Time       │
                        │ Machine GameState │
                        └───────────────────┘
```

Regras:
- Um sistema **nunca** referencia nós de cena diretamente; emite sinais.
- Todo sistema com estado implementa `get_save_data()` / `load_save_data(d)` e se
  registra no `SaveSystem`.
- Atributos do jogador são **derivados**: `UpgradeSystem.get_stat("tool_power")` =
  base (`data/config/player.json`) + efeitos dos upgrades. Nenhum script guarda
  "dano da picareta" fixo.
- Números de balanceamento ficam em JSON, não no código.

### Autoloads (ordem de carga)

| Autoload | Responsabilidade |
|---|---|
| `EventBus` | Sinais globais (toast, inventário, dinheiro, exposição, local, etc.). |
| `DataManager` | Carrega e valida `data/`; registros por id; carrega texturas com fallback. |
| `Controls` | Registra o mapa de entrada a partir de `data/config/controls.json`. |
| `GameState` | Seed do mundo, local atual, profundidade máxima, elevador, flags, estatísticas, notas. |
| `TimeSystem` | Relógio do dia (06:00→02:00), dias, dormir. |
| `EconomySystem` | Dinheiro, preço de venda (com gancho para mercado/inflação), compras. |
| `InventorySystem` | Slots com pilhas, hotbar 1–9, capacidade derivada de upgrades. |
| `UpgradeSystem` | Trilhas de upgrade por nível, requisitos, efeitos → atributos derivados. |
| `HealthSystem` | Vida e energia do jogador (persistem entre cenas). |
| `RadiationSystem` | Fontes de radiação, taxa atual, exposição acumulada, proteção, efeitos. |
| `MachineSystem` | Automação: máquinas da base, combustível, produção por tempo. |
| `AudioSystem` | SFX por id com pool de players, loops de ambiente, Geiger. |
| `SaveSystem` | JSON versionado em `user://saves/`, migrações. |
| `SceneManager` | Troca de área com fade, spawn do jogador, desmaio/resgate. |
| `UIManager` | Pilha de painéis modais; bloqueia input do jogador quando há painel aberto. |

## 4. Árvore de cenas

```
title_screen.tscn          Menu (novo jogo + seed / continuar / sair)
main.tscn  (Main)
├─ WorldRoot (Node2D)      ← área atual instanciada aqui
│   ├─ base.tscn           BaseArea: mapa ASCII → TileMapLayers + props + interativos
│   └─ mine_level.tscn     MineLevel: gerado por MineGenerator(seed, profundidade)
│       ├─ Floor (TileMapLayer)
│       ├─ Walls (TileMapLayer, colisão + oclusores de luz)
│       ├─ Entities (Node2D, y-sort)  rochas, props, pickups, Player
│       ├─ Lights                      lâmpadas, brilho radioativo
│       └─ CanvasModulate              escuridão
├─ HUD (CanvasLayer)       barras, Geiger analógico, dinheiro, relógio, local, hotbar, toasts
├─ PostFX (CanvasLayer)    vinheta, granulação, interferência por radiação (shader)
├─ Menus (CanvasLayer)     Inventário, Terminal (loja), Pausa, Diálogo, Notas
└─ Fade (CanvasLayer)
player.tscn                CharacterBody2D + AnimatedSprite2D + ferramenta + lanterna
rock.tscn                  StaticBody2D: vida, rachaduras, tremor, partículas, drops
pickup.tscn                Item físico: salto em arco, ímã até o jogador
interactables/*.tscn       Terminal, Trailer, Chuveiro, Entrada da mina, Escadas, Máquinas, NPC
```

## 5. Estrutura de diretórios

```
autoload/        sistemas globais (um arquivo por sistema)
scenes/          .tscn agrupadas por domínio (main, player, world, mines, mining, buildings, machines, npc, ui)
scripts/         lógica de cena e utilitários (core, player, world, mining, machines, ui)
data/            TODO conteúdo do jogo em JSON
  config/        game.json, player.json, controls.json
  items/ ores/ upgrades/ machines/ areas/ mines/ npcs/ lore/ audio/ tiles/ shop/
assets/          PNG/WAV/fonte (placeholders substituíveis)
shaders/         post-processamento e efeitos
tools/           gen_assets.py (gera placeholders), smoke_test
docs/            este documento, referências históricas
```

## 6. Modelo de dados (resumo)

**Item** `data/items/*.json`
`id, name, category(ore|material|component|tool|consumable|lore), rarity, value, stack, radiation, icon, desc, use{energy,hp,exposure}`

**Minério/Rocha** `data/ores/ores.json`
`id, name, drop, drop_min, drop_max, hp, min_tier, radiation, min_depth, max_depth, spawn_weight, vein[min,max], sprite, particle_color, glow`

**Upgrade (trilha)** `data/upgrades/upgrades.json`
`id, name, category, levels[ {name, cost, items{}, requires{upgrades{}, max_depth}, set{stat:valor}, add{stat:valor}, sprite, desc} ]`
Nível 0 = estado inicial. `set` substitui (ex.: tipo de ferramenta), `add` acumula (bônus).

**Máquina** `data/machines/machines.json`
`id, name, requires_upgrade, fuel{item, minutes_per_unit, capacity}, interval_minutes, output_table[{item, weight}], buffer, sprite`

**Bioma de mina** `data/mines/biomes.json`
`id, name, min_depth, max_depth, size, rock_density, ambient_rad, rad_per_depth, darkness, room_types{tipo:peso}, lamps, ore_mult{}`

**Evento de nível** `data/mines/events.json`
`id, name, chance, min_depth, effects{dark, rad_mult, ore_mult, extra_room}`

**Áreas** `data/areas/base.json` — mapa em ASCII + legenda (tile e/ou objeto por caractere).

**Save** `user://saves/slot_1.json`
```json
{ "save_version": 1, "saved_at": "...", "systems": { "game_state": {...}, "inventory": {...},
  "economy": {...}, "upgrades": {...}, "health": {...}, "radiation": {...},
  "time": {...}, "machines": {...} } }
```
Cada sistema serializa a própria chave. `SaveSystem.MIGRATIONS` converte versões antigas.

## 7. Geração procedural da mina

Determinística: `rng.seed = hash([world_seed, depth])`. Mesma seed + mesmo nível = mesma mina.

1. **Bioma** pela profundidade (faixas em `biomes.json`).
2. **Salas**: retângulos sem sobreposição; cada sala recebe um **tipo** sorteado por peso
   (galeria natural, câmara escorada, depósito, ventilação, posto de controle,
   zona inundada, bolsão quente). O tipo define forma (caverna por autômato celular
   vs. retangular) e decoração.
3. **Conexões**: árvore geradora mínima entre centros (+ 1–2 laços), túneis em L de
   2 tiles; biomas industriais ganham trilhos.
4. **Entrada** na primeira sala, **poço de descida** na sala mais distante (BFS).
5. **Caminho garantido** entrada→saída sem rochas (nunca trava o jogador por tier).
6. **Rochas** por densidade do bioma; minérios por peso filtrado pela profundidade,
   crescendo em **veios** (passeio aleatório a partir de uma semente).
7. **Props** encostados nas paredes conforme o tipo de sala (lâmpadas, escoras, barris,
   armários, ventiladores, placas, documentos).
8. **Evento de nível** opcional (queda de energia, vazamento, veio rico...).

Uma mina é gerada **nível a nível, sob demanda**; só o nível atual existe em memória.
Para mapas grandes futuros (superfície aberta), o plano é chunks de 32×32 tiles.

## 8. Fluxo do jogo

```
Título → Novo jogo (seed) → BASE (dia 1, 06:00)
  BASE: terminal (vender/comprar) · trailer (dormir/salvar) · chuveiro (descontaminar)
        gerador + perfuratriz (automação) · entrada da mina (elevador)
  MINA nível N: minerar → coletar → gerenciar exposição/espaço/energia/hora
        poço ↓ = nível N+1   escada ↑ = volta à base
  Desmaio (vida 0, exposição 100% ou 02:00) → resgate para a base, perde parte da carga + taxa
  Dormir → novo dia, energia cheia, exposição reduzida, máquinas produzem, autosave
```

## 9. Vertical slice (esta entrega)

Base com mapa · personagem de traje amarelo (4 direções, andar/correr/golpear) · câmera
com limites · colisão · mina procedural infinita por níveis · mineração com feedback
(tremor, flash, rachaduras, partículas, números, hit-stop, som, drops físicos com ímã)
· 7 recursos minerais + materiais de caixas · inventário com hotbar e painel ·
terminal de comércio (vender/comprar) · dinheiro · upgrades (picareta → britadeira,
traje, mochila, lanterna, revestimento de chumbo, elevador, gerador, perfuratriz) ·
radiação (ambiente, rochas, barris, carga) com Geiger analógico e cliques aleatórios
· escuridão + lanterna + lâmpadas piscando · relógio/dias · save/load versionado ·
NPC comerciante · notas de lore · primeira máquina automática.

## 10. Roadmap

| Fase | Conteúdo |
|---|---|
| **0 — Slice** (agora) | Ciclo minerar → coletar → vender → melhorar → minerar mais. |
| 1 — Polimento do ciclo | Balanceamento por playtest, mais sons, tutorial contextual, opções (volume, tela cheia). |
| 2 — Base e automação | Construção livre em grade, esteiras, triturador, refinaria (processamento), depósito, energia como rede. |
| 3 — Mundo | Mapa de regiões (floresta, vila, ferro-velho, depósito ferroviário), licenças, veículo. |
| 4 — Perigos | Gás, falta de O₂, desabamentos, inundação, eletricidade, chuva radioativa (WeatherSystem). |
| 5 — Gestão | Trabalhadores, contratos, mercado com variação de preço, pesquisa (árvore). |
| 6 — Exploração | Instalações autorais (bunker, laboratório, usina), segredos, fitas/rádio, eventos com decisões. |
| 7 — Endgame infinito | Profundidade sem fim com escalonamento, prestígio/expansão de operação. |
