# CÂMARA 7

Abril de 1986. Mineração, radiação, horror ambiental e automação numa mina **fictícia**
perto de Chernobyl. Descubra o que aconteceu com o Turno C — e o que há atrás da Câmara 7.
Godot 4.7 · GDScript · 2D pixel art (escala inteira automática, ~640×360 virtual).

## Baixar e jogar

Baixe o instalador `Camara7-<versão>.msi` em **[Releases](https://github.com/kerlonr/camara-7/releases)**
(o release mais recente que tiver um .msi). Ele instala no seu usuário (`%LOCALAPPDATA%\Programs\Camara 7`),
sem pedir administrador, e cria atalhos no Menu Iniciar e na Área de Trabalho.

O Windows pode avisar "O Windows protegeu o computador" (o instalador não tem assinatura digital):
**Mais informações → Executar assim mesmo**.

### Atualizações automáticas

Ao abrir, o jogo consulta o último release deste repositório. Se houver versão nova, ele baixa só o
conteúdo (`Camara7.pck`, ~4 MB), confere o SHA-256 e aplica quando você fecha o jogo (ou na hora, em
**Reiniciar e atualizar** na tela inicial). Saves não são tocados. Dá para desligar em *Opções*.
Se uma versão exigir um motor Godot novo, o jogo avisa e abre a página do instalador.

## Desenvolvimento

- **Rodar do código:** `Jogar.bat` (Godot portátil em `C:\Users\mitok\Tools\Godot`) ou `Abrir no Editor.bat` + **F5**.
- **Publicar uma atualização para os jogadores:** `Publicar Atualizacao.bat`. Ele sobe a versão, roda os
  testes, exporta o `.pck`, faz commit + tag e cria o release no GitHub (`tools/publish_update.ps1`;
  `-Installer` também gera e anexa o `.msi`, necessário só no primeiro release ou se o motor mudar).
- **Gerar só os arquivos:** `Gerar EXE.bat` (`dist\Camara 7.exe` + `Camara 7.pck`) e `Gerar Instalador.bat`
  (WiX Toolset 3 em `C:\Users\mitok\Tools\wix3`; ícone aplicado com o rcedit).
- **Arte e som:** `python tools/build_art.py` e `python tools/gen_audio.py` (tudo é gerado por código).

### Controles

| Tecla | Ação |
|---|---|
| WASD / setas | Andar |
| SHIFT | Correr |
| Mouse esquerdo (ou Espaço) | Minerar / usar item selecionado (segure para golpear em sequência) |
| E | Interagir (terminal, trailer, chuveiro, mina, escadas, NPCs, máquinas) |
| 1–9 / roda do mouse | Selecionar item da barra rápida |
| TAB / I | Mochila (abas Itens e Status; clique esq. move, clique dir. usa consumível) |
| K | Talentos (aparece "[K] TALENTO" no canto quando há escolha pendente) |
| F | Liga/desliga a lanterna |
| Mouse esquerdo com sinalizador/dinamite | Arremessa na direção do mouse |
| ESC | Menu (salvar, carregar, controles, sair) |
| J | Diário (missões, fitas, notas) |
| 1–9 em diálogos | Escolher resposta |
| F11 | Tela cheia / janela |
| F3 | Informações de depuração (FPS, seed, profundidade, nº da descida) |

### A história

28 de abril de 1986. Você chega ao Posto Zaliv, a nove quilômetros da usina. Na noite da
explosão, o Turno C desceu ao setor fundo da mina e não voltou. Converse com **Oksana**,
**Kolya**, **Baba Hanna** e o **Dr. Abramov** (os dois últimos chegam com o passar dos dias).
Ache as **cinco fitas** do mestre Petrenko nas profundezas (a partir do nível 4) e chegue à
**Câmara 7**, no nível 30. Há dois finais. Depois do final, a mina continua infinita.

### O ciclo

1. Na **base**, entre na mina (castelete à direita, tecla E).
2. **Minere** rochas e veios. Os itens saltam e são puxados até você.
3. Fique de olho na **energia** (golpes gastam), no **espaço da mochila**, na **hora**
   e na **exposição** (Geiger: ponteiro, LED e cliques).
4. **Desça** pelo poço (escada no chão) ou **suba** pela escada de entrada para voltar.
5. No **terminal**: venda a carga, compre suprimentos e **melhorias**.
6. **Durma** no trailer: novo dia, energia cheia, exposição menor, **save automático**.
7. Melhorias mudam o jogo de forma visível: picareta → **britadeira** (segurar = golpes contínuos),
   traje com nova cor e proteção, lanterna mais forte, mochila maior, revestimento de chumbo,
   **elevador** (níveis 5, 10, 15...), **gerador a carvão** e **perfuratriz automática** na base.

Desmaiar (vida 0, exposição 100% ou 02:00) = resgate para a base, taxa e perda de parte da carga.

**Cada descida gera uma mina diferente** (salas, eventos, perfil de minérios), mas é
reproduzível pela seed + número da descida. Há veios ricos (brilham), geodos e, às vezes,
minério de níveis mais fundos aparecendo cedo. Fique atento a sons e sombras.

### Novidades da v0.6

- O jogo agora se chama **Câmara 7** (logotipo novo).
- Atualização automática pelo GitHub; instalador por usuário (sem administrador).

### Novidades da v0.5.1 — tela inicial

- Tela inicial refeita: a noite de 26 de abril de 1986. A unidade 4 aberta e em chamas, a coluna de luz azulada
  sobre o reator (relatada por testemunhas), fumaça indo com o vento, fagulhas, Pripyat ao fundo com as janelas
  ainda acesas, um Mi-8 cruzando o brilho e o protagonista de costas na cerca, com o lampião.
- Abertura de 3 s (escuro, Geiger acelerando, a cena surge, o letreiro acende falhando) — qualquer tecla pula.
- Logotipo novo, cena em pixel inteiro (sem distorção em nenhum zoom) e enquadramento que se adapta à tela.

### Novidades da v0.5

- **Inimigos que fazem sentido estar ali** (cada um com uma regra, estilo Darkwood):
  - *Rato da galeria* (mina, nível 2+): fraco e rápido; luz e barulho atraem. Lanterna apagada e passo leve = passa despercebido.
  - *Cão da Zona* (superfície, à noite, a partir do dia 3): cães deixados na evacuação. Não chegam perto do fogo nem de sinalizador.
  - *Vulto* (mina, nível 12+): só existe no escuro e vem por trás. A picareta atravessa; a luz da lanterna queima — vire-se e aponte.
  - Justiça: todo ataque é telegrafado (dá para desviar), invulnerabilidade curta após levar dano, no máximo 2 atacando,
    nenhum golpe tira mais de 12% da vida, nada nasce na sua frente e a força cresce com profundidade/dias **com teto**.
  - Olhos que brilham no escuro, bestiário no diário (aba Catálogo) com a fraqueza de cada um.
- **Lanterna liga/desliga (F)**: economiza bateria e esconde você dos ratos — mas no escuro o Vulto se aproxima.
- **Traços** (escolha única no começo, estilo RPG clássico): cada um com vantagem e desvantagem. Saves antigos ganham a escolha.
- **Encontros especiais** raros na mina (o mineiro sentado, o rádio na sala vazia, o esconderijo do Kolya, o círculo de capacetes…).
- **HUD de equipamento real**: dosímetro de caneta (tipo DKP-50) com a dose acumulada e radiômetro com escala em мР/ч.
- **Sons mais assustadores**: arranhões dentro das paredes, gritos distantes, rosnados, a respiração do Vulto e uma camada
  de pavor que cresce quando algo te persegue. Tela inicial com relâmpagos, trovão e corvos.
- Arte revisada: contornos que estavam cortados na borda, furos de transparência, ferramentas e 15 objetos redesenhados.
  Auditoria automática em `tools/audit_art.py`.

### Novidades da v0.4 (arte)

- Toda a pixel art foi refeita ou polida: sombras frias e luzes quentes (*hue shifting*), contorno seletivo,
  rochas facetadas, pisos e paredes sem "chuvisco", personagens com mais detalhe.
- Sombra de contato no chão junto às paredes; gradação de cor de cinema; vinheta que pulsa quando a vida está
  baixa, a exposição alta ou você está fundo demais.
- Marcas do que aconteceu lá embaixo: rastros, mãos na parede, trajes largados, pichações.
- Arte gerada por código: `python tools/build_art.py` (gera tudo na ordem certa).
- v0.4.1: tela de menu nova e animada (usina à noite, neblina, holofote, parallax pelo mouse); letras em cirílico
  em pixel art (fonte Pixelify Sans, OFL) no rádio e nas placas; dia na base um pouco mais quente.

### Novidades da v0.3

- **Experiência e talentos** (inspirado em RPGs clássicos): minerar, descobrir minérios novos, cumprir
  contratos e missões dá XP. A cada nível, escolha 1 de 3 talentos. Alguns são poderosos, mas cobram um
  preço (ex.: *Ganância* dobra os veios ricos, mas desmaiar faz perder toda a carga).
- **Contratos diários** no terminal: pedidos com prazo que pagam mais que o balcão e dão XP.
- **Bancada de trabalho** (perto da Oksana): sinalizadores, pilhas, dinamite, filtros e kits médicos.
- **Lanterna em cone** que segue o mouse e gasta **bateria** (o halo do visor nunca apaga totalmente).
  Sinalizadores iluminam por 90 s; dinamite quebra tudo num raio (cuidado com a explosão).
- **Catálogo** de descobertas no diário. **Rádio** redesenhado como um aparelho de verdade:
  gire o dial (arraste o botão, roda do mouse ou A/D) até o sinal fechar.
- HUD novo e limpo, como equipamento real: relógio de pulso + data, barras finas de vida/energia,
  dosímetro, contador Geiger analógico (só quando importa), bateria da lanterna, nível e dinheiro.
  As placas ficam transparentes quando o personagem passa por trás delas.
- Saves da v0.2 são convertidos automaticamente: você recebe um nível proporcional ao progresso e
  os talentos correspondentes para escolher.

### Opções e acessibilidade

Tela cheia (padrão; F11 alterna), **zoom da tela** (Perto/Médio/Longe — a resolução se
ajusta sozinha mantendo o pixel nítido), volumes separados (música, ambiente, efeitos,
interface), tremor de tela, flashes, números de dano, **legendas de sons** e dicas.

**Dica:** a partir do nível 6 aparece chumbo (precisa da picareta de ferro); do 12, urânio
(radioativo, vale muito, mas irradia quem carrega); no 20 começa a Zona Quente.

## Estrutura

```
autoload/   sistemas globais (EventBus, DataManager, Inventory, Economy, Upgrade, Radiation,
            Health, Time, Machine, Audio, Save, SceneManager, UIManager, GameState, Controls)
scenes/     cenas (.tscn) por domínio
scripts/    lógica de cena: player, mining, mines (gerador procedural), world, machines, npc, ui
data/       TODO o conteúdo em JSON (itens, minérios, upgrades, biomas, salas, eventos,
            máquinas, NPCs, notas, sons, mapa da base, atmosfera, controles)
assets/     pixel art e sons PLACEHOLDER (gerados por tools/gen_assets.py)
shaders/    pós-processamento (neblina, granulação, vinheta, interferência da radiação)
tests/      smoke_test (ciclo completo), capture (screenshots), check_scripts
docs/       DESIGN.md (arquitetura, roadmap) · REFERENCIAS.md (real × inspirado × fictício)
```

## Como adicionar conteúdo (sem mexer em código)

| Quero... | Edite |
|---|---|
| Novo minério | `data/items/items.json` (o item) + `data/ores/ores.json` (a rocha: hp, tier, profundidade, peso, sprite) |
| Novo upgrade / novo nível | `data/upgrades/upgrades.json` (`set` substitui atributo, `add` soma) |
| Novo bioma / faixa de profundidade | `data/mines/biomes.json` |
| Novo tipo de sala | `data/mines/rooms.json` e referencie o peso no bioma |
| Novo evento de nível | `data/mines/events.json` |
| Nova máquina | `data/machines/machines.json` + uma trilha de upgrade com o `stat` dela |
| Mudar a base | `data/areas/base.json` (mapa ASCII + lista de objetos) |
| Novo prop/decoração | `data/world/props.json` |
| Falas de NPC | `data/npcs/npcs.json` (com condições: `exposure>60`, `max_depth>=10`, `upgrade:tool>=3`...) |
| Notas, fitas, registros de terminal | `data/lore/notes.json` |
| Diálogos ramificados | `data/story/dialogues.json` (condições como `tapes>=3`, `quest_done:q_radio`) |
| Missões | `data/quests/quests.json` |
| Intro, cenas e finais | `data/story/scenes.json` |
| Rádio | `data/story/radio.json` |
| Fitas/itens de história na mina | `data/story/placements.json` |
| Fenômenos estranhos | `data/mines/phenomena.json` |
| Dicas | `data/story/hints.json` |
| Mais sombrio / menos sombrio | `data/config/atmosphere.json` (luz por hora, saturação, vinheta, neblina, chuva) |
| Balanceamento geral | `data/config/game.json`, `data/config/player.json`, `data/shop/shop.json` |
| Teclas | `data/config/controls.json` |
| Nome do jogo | `data/config/game.json` (`title`) e `project.godot` (`config/name`) |

**Trocar arte/som:** sobrescreva o PNG/WAV com o mesmo nome e tamanho. Para regenerar os
placeholders: `python tools/gen_assets.py` (arte) e `python tools/gen_audio.py` (som).

## Boas práticas aplicadas

- **HUD por urgência**: vida/energia/exposição no canto, Geiger só quando importa, relógio e
  dinheiro no outro canto, missão numa linha; avisos curtos com fundo sólido.
- **Acessibilidade**: legendas de sons ligadas por padrão, opções de tremor/flash, volumes
  separados, texto grande sobre fundo escuro.
- **Som de horror**: drones graves (30–60 Hz) com batimento, camadas de ambiente,
  respiração na máscara, batimento cardíaco em perigo e *silêncio* usado de propósito.

Fontes: [Rocketbrush — HUD](https://rocketbrush.com/blog/designing-practical-and-pretty-hud-in-video-games),
[Pixelwolf — diegético × HUD](https://pixelwolf.net/blog/?post=game-ui-diegetic-hud-hybrid-comparison),
[Can I Play That? — opções básicas](https://caniplaythat.com/2019/07/11/basic-accessibility-options-for-deaf-hoh-players/),
[Xbox Accessibility Guideline 104](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/104),
[Althera — som em jogos de horror](https://altheragames.com/en/blog/horror-game-sound-design),
[Mowjera — silêncio no horror](https://mowjera.com/blog/horror-game-sound-design-silence).

## Testes

`Rodar Testes.bat` executa `tests/smoke_test.tscn`: geração determinística, 40 níveis com
caminho garantido, mineração por input simulado, coleta, radiação, venda, upgrades,
automação, save/load, desmaio, painéis, descontaminação, dormir, diálogos, missões, fitas,
rádio, final e migração de save. Os testes usam `user://test_saves/` e nunca tocam no save real.

## Save

`%APPDATA%\Godot\app_userdata\Chernobyl Miner — Prototype\saves\slot_1.json`
(JSON legível com `save_version` para migrações futuras). A pasta mantém o nome antigo do projeto de propósito,
para saves de versões anteriores continuarem funcionando.
