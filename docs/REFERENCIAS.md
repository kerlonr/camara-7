# Referências: real × inspirado × fictício

O jogo é **ficção** ambientada em abril/maio de 1986. Esta tabela separa o que é fato
histórico do que foi apenas inspirado e do que foi inventado para o gameplay. Ao adicionar
conteúdo, classifique-o aqui. Na intro e no rádio, cada trecho tem a etiqueta
**[FATO HISTÓRICO]** ou **[FICÇÃO]**.

## Fatos históricos (usados como pano de fundo)

| Elemento | Onde aparece | Nota |
|---|---|---|
| Explosão do reator nº 4 da usina de Chernobyl, 26/04/1986, 01:23 | intro, fitas, relógios parados | Ucrânia, então URSS. |
| Evacuação de Pripyat em 27/04/1986, anunciada pelo rádio como temporária; moradores ouviram que seria por "três dias" | intro, rádio (parafraseado), fala do Kolya | Ônibus a partir das 14h. O jogo **não** reproduz Pripyat. |
| Anúncio oficial do acidente em 28/04/1986 | rádio (texto parafraseado, curto) | Dia 1 do jogo = 28/04/1986. |
| Cerca de 400 mineiros de Tula e do Donbass cavaram um túnel sob o reator 4 (maio–junho de 1986) para um sistema de resfriamento | intro, epílogo | O protagonista é *inspirado* neles, mas trabalha numa mina fictícia. |
| "Floresta Vermelha": pinheiros que morreram e ficaram avermelhados após o acidente | pinheiros ruivos na base, fala da Hanna | — |
| Desfile do 1º de Maio de 1986 em Kyiv ocorreu normalmente | rádio, Kolya (dia 4) | — |
| Roda-gigante de Pripyat, prevista para inaugurar em maio de 1986 | tela de título (silhueta), nota "Foto rasgada" | Aparece só como silhueta e lembrança. |
| Slogan soviético "átomo pacífico" | cartaz "МИР" | Propaganda real da época, aqui em versão estilizada. |
| Moradores idosos que se recusaram a sair ou voltaram à Zona | Baba Hanna | O fenômeno existiu; a personagem é fictícia. |
| Iodeto de potássio protege a **tireoide** contra iodo radioativo | item "Iodeto de potássio" | A descrição explica o limite real. O efeito de jogo (-30% de exposição) é ficção. |
| Crença popular de que álcool protegia da radiação (**falsa**) | item "Samogon", nota "Recibo de vodka" | O jogo diz explicitamente que é mito. |
| Símbolo de radiação, contadores Geiger, máscaras de gás soviéticas | HUD, placas, personagem | Estética real; equipamentos genéricos. |

## Apenas inspirado

| Elemento | Nota |
|---|---|
| Traje amarelo do protagonista | Inspirado em trajes de proteção; design próprio. |
| Ônibus abandonado na base | Lembra os ônibus da evacuação; modelo genérico. |
| Paredes bicolores, azulejos, placas hexagonais, cartazes, faixa "СЛАВА" | Estética soviética genérica. |
| Computador "ЭВМ-7" com bobinas de fita | Lembra computadores da época; nome inventado. |
| Atmosfera "retrofuturista" de terminais e fitas | Pegada inspirada em jogos pós-apocalípticos, **sem** nomes, marcas ou elementos de Fallout (propriedade da Bethesda). |

## Ficção (gameplay e história)

| Elemento | Nota |
|---|---|
| Mina Krasnyi Yar, Posto Zaliv, vila de Zaliv | Lugares inventados. |
| Turno C, mestre Petrenko, Dmytro Melnyk, fitas, Câmara 7, "veia azul", código 2604 | História inventada. O "mineral anômalo" é ficção. |
| Kolya, Oksana, Hanna, Dr. Abramov, Instituto de Física Aplicada nº 7 | Personagens e instituição inventados. |
| Registros do terminal, transmissões de números, "Turno C no rádio" | Ficção. |
| **Exposição (%)**, CPS do Geiger, chuveiro e soluções que "zeram" exposição | Abstrações de jogo, **não** dose real (Sv) nem tratamento real. |
| Distribuição de minérios, geodos e veios ricos | Inventados. |
| Fenômenos estranhos (sombras, sussurros, batidas) | Ficção de horror ambiental. Não há monstros. |

## v0.3 — o que é invenção

| Elemento | Natureza |
|---|---|
| Talentos (Lábia, Corpo Fechado, Ganância...) e níveis de experiência | Mecânica de jogo. Inspiração no *gênero* de RPG clássico; nenhum nome, sistema ou texto copiado. |
| Contratos (gerador do hospital, equipe do aterro etc.) | Ficção. Os clientes são inventados. |
| Rádio "Залів-7" (Zaliv-7) | Aparelho inventado, com visual inspirado em rádios soviéticos de mesa dos anos 70/80. |
| Música da base (lamento dedilhado em ré, modo "dórico ucraniano") | Composição original sintetizada no estilo de bandura; não é uma canção folclórica real. |
| Pilha "45" | Referência genérica às pilhas quadradas de 4,5 V comuns na URSS. |
| Inspiração de clima | Jogos de sobrevivência sombrios em visão de cima (atmosfera, luz em cone, escassez) — só a sensação, sem elementos de nenhum jogo específico. |

## v0.4 — arte

| Técnica / referência | Onde |
|---|---|
| *Hue shifting*: sombras puxam para o frio, luzes para o quente ([Derek Yu – Pixel Art Basics](https://www.derekyu.com/makegames/pixelart.html)) | `tools/polish.py` → `hramp()`, aplicado em todos os sprites |
| Contorno seletivo (*sel-out*) e anti-aliasing manual ([Pixel Parmesan – Anti-Aliasing](https://pixelparmesan.com/blog/anti-aliasing-fundamentals-for-pixel-artists), [Ricky Han – selective outlining](https://rickyhan.com/jekyll/update/2019/09/01/pixel-art-algorithm-selective-outlining-anti-aliasing.html)) | `polish_sprite()` |
| Clima de luz recortada no escuro, "mostrar só o necessário" (análises da atmosfera de Darkwood) | lanterna em cone, sombra de contato nas paredes, vinheta que pulsa com o pavor |
| Rochas facetadas (faces Voronoi iluminadas de cima/esquerda) | `tools/rocks_v4.py` |
| Pisos com manchas grandes e pontilhado só nas transições | `tools/tiles_v4.py` |
| "НЕ ИДИ ВНИЗ" | Russo para "não desça". Pichação fictícia nas galerias. |

## v0.5 — fatos e ficção

| Elemento | Natureza |
|---|---|
| Cães abandonados na evacuação de Pripyat (1986) | **Fato.** Moradores foram orientados a deixar os animais; equipes de liquidação foram enviadas para abatê-los. No jogo, o "Cão da Zona" é inspirado nisso. |
| Dosímetro de caneta (tipo DKP-50) e radiômetro DP-5 | **Fato.** Instrumentos soviéticos reais usados pelos liquidantes. A escala do jogo (50 R = desmaio) é simplificada. |
| Relógio parado em 1h23 | **Fato:** a explosão foi às 01:23 de 26/04/1986. |
| Janelas acesas na usina | **Fato:** as unidades 1–3 continuaram operando depois de 1986 (a última foi desligada em 2000). |
| Ratos, Vulto, encontros especiais, traços | Ficção de jogo. O Vulto não é baseado em nenhuma lenda real. |
| "Esconderijo do Kolya", "círculo de capacetes" | Ficção. |

