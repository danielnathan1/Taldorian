# TALDORIAN TCG — Documentação Completa do Projeto

> **Versão do documento:** Maio 2026  
> **Plataforma:** Godot 4 · GDScript  
> **Modo:** Multiplayer LAN (ENetMultiplayerPeer)  
> **Inspiração:** Flesh and Blood  

---

## SUMÁRIO

1. [Visão Geral do Projeto](#1-visão-geral-do-projeto)
2. [O que Está Pronto e o que Falta](#2-o-que-está-pronto-e-o-que-falta)
3. [Heróis — Status e Arte](#3-heróis--status-e-arte)
4. [Catálogo Completo de Cartas](#4-catálogo-completo-de-cartas)
5. [Como Jogar (How to Play)](#5-como-jogar-how-to-play)
6. [Planejamento para o Alpha](#6-planejamento-para-o-alpha)
7. [Próximos Passos Detalhados](#7-próximos-passos-detalhados)

---

## 1. VISÃO GERAL DO PROJETO

**Taldorian TCG** é um card game tático para dois jogadores desenvolvido em **Godot 4**.  
Cada jogador monta um time de **3 heróis** e um deck de cartas, e batalha pela eliminação total dos heróis adversários.

### Diferenciais em relação a outros TCGs

| Diferencial | Descrição |
|-------------|-----------|
| **3 heróis por jogador** | Cada jogador controla um time de 3 heróis, cada um com stats, habilidades e identidade própria |
| **Herói oculto (blefe)** | O herói ativo começa face-down — o oponente não sabe qual está na linha de frente |
| **Cadeia de símbolos** | As cartas jogadas formam uma cadeia de elementos (Fogo, Terra, Água, Ar) que ativa habilidades dos heróis |
| **Exaustão rotativa** | Heróis se esgotam após combater, forçando rotação estratégica do time |
| **Timing estruturado** | ACTION → janela de REACTION → BONUS_ACTION, com espaço para contra-jogo |
| **Habilidades de retaguarda** | Heróis que não estão na frente ainda podem interagir (ex: Ieldor causa dano direto) |

### Arquitetura Técnica

O projeto segue separação rígida de responsabilidades:

- **`src/core/`** — Lógica pura de jogo. Sem UI, sem nodes. Roda apenas no servidor.
- **`src/entities/`** — Modelos de dados (heróis, cartas, efeitos). Sem UI.
- **`scenes/`** — Somente visual e interação. Nunca contém regras de jogo.
- **`GameBus`** — Autoload central de signals. Toda comunicação entre sistemas passa por aqui.

---

## 2. O QUE ESTÁ PRONTO E O QUE FALTA

### ✅ Implementado

#### Sistema de Jogo Core
- [x] Lobby com conexão LAN (host e join por IP)
- [x] Sincronização de estado via RPC (`_sync_state`)
- [x] GameState com autoridade única no servidor
- [x] Todas as fases do jogo: `OPENING_MULLIGAN → DRAW → HERO_SELECTION → BACKLINE_ABILITY → ACTION → COMBAT → END`
- [x] Sistema de turno e segmento (2 segmentos por rodada, combate ao fim de ambos)
- [x] Timing estruturado: ACTION → janela de REACTION → BONUS_ACTION
- [x] Lógica de herói face-down com revelação condicional
- [x] Arsenal (1 carta, regras especiais ao jogar do arsenal)
- [x] Sistema de mulligan de abertura (devolver 2 cartas, comprar até 6)
- [x] Exaustão rotativa de heróis
- [x] Detecção de derrota (HP ≤ 0) e tela de resultado (vitória/derrota)

#### Combate
- [x] Resolução de dano bidirecional (`CombatResolver`)
- [x] Todos os modificadores `pending_*` (bônus de ataque/defesa, escudo, ricochet, etc.)
- [x] Efeitos cross-round (`next_round_bonus_attack`)
- [x] Preview de dano em tempo real na `CenterBar`
- [x] Animação de resolução de combate

#### Heróis
- [x] 6 heróis implementados: Poppy, Irena, Hakai, Ieldor, Nissin, Valkar
- [x] Sistema de habilidades ativas via cadeia de símbolos
- [x] Passivas funcionais para todos os 6 heróis
- [x] Habilidade de retaguarda interativa (Ieldor — fase BACKLINE_ABILITY)

#### Cartas e Efeitos
- [x] 84 cartas no Set Base (`data/cards/taldorian_origins.json`)
- [x] Sistema de efeitos modular (`CardEffect` + `CardEffectRegistry`)
- [x] 70+ implementações concretas de efeitos em `src/entities/effects/`
- [x] Raridades: Common, Rare, Legendary, Mystic
- [x] Cartas furtivas (`is_stealth`)
- [x] Overlays dinâmicos: `PickCard`, `PickSymbol`, `DiscartCard`, `BacklineAbility`

#### Interface (UI)
- [x] Tabuleiro principal (`boardv2`) com `HalfBoard` e `CenterBar`
- [x] Tela de seleção de herói (`HeroPickScreen`)
- [x] Tela de mulligan (`MulliganScreen`)
- [x] Mão do jogador com drag & drop
- [x] Preview de carta ao passar o mouse
- [x] `HeroSlot` (componente reutilizável com face-down)
- [x] `CardView` (componente reutilizável com face-down)
- [x] Animações: compra de carta, jogar carta, transição de turno, VFX (chuva de flechas, cura)

#### Persistência e Coleção
- [x] `DeckStore` — salva/carrega decks do jogador em `user://`
- [x] `Collection` — catálogo de cartas disponíveis para o jogador
- [x] `CosmeticsStore` — sleeves e playmats desbloqueáveis
- [x] Playmats: Default, Catedral, Floresta

#### Mundo Aberto (Sistema Separado)
- [x] Mundo tile-based multiplayer LAN
- [x] Personagem do jogador com movimento
- [x] Tela de conexão separada do TCG
- [x] Sistema de chat básico

---

### ❌ Pendente / A Implementar

#### Alta Prioridade (Bloqueadores do Alpha)
- [x] **Deck Builder** — tela completa com `card_picker`, `deck_rail`, `hero_picker`, filtros, validação e persistência via `DeckStore` (`scenes/ui/deck_builder/`)
- [x] **Seleção de deck no lobby** — botão "Deck Builder" integrado no lobby abre a tela antes de entrar na partida
- [ ] **Arte das cartas** — 75 das 84 cartas sem ilustração finalizada
- [ ] **Arte do herói Nissin** — único herói sem imagem

#### Média Prioridade (Qualidade do Alpha)
- [ ] **Tutorial / Onboarding** — modo solo ou sandbox para aprender o jogo
- [ ] **Modo solo/IA** — oponente bot mesmo que básico para testes offline
- [ ] **Tela de coleção** — visualizar e organizar todas as cartas obtidas
- [ ] **Histórico de partidas** — log das últimas partidas
- [ ] **Tela de perfil** — nome, avatar, estatísticas W/L
- [ ] **Sons e música** — SFX para cada ação (jogar carta, dano, cura, habilidade)
- [ ] **Animações de habilidade** — VFX individuais por herói/habilidade
- [ ] **Indicador de fase/turno** melhorado — HUD mais claro sobre quem age e em qual fase

#### Baixa Prioridade (Pós-Alpha)
- [ ] **Novos heróis** — expansão além dos 6 atuais
- [ ] **Novo set de cartas** — expansão além das 84 atuais
- [ ] **Matchmaking online** — conexão via relay/servidor dedicado (atualmente só LAN)
- [ ] **Sistema de progressão** — desbloquear cartas e cosméticos
- [ ] **Modo draft/sealed** — construção de deck com pool limitado
- [ ] **Replay de partidas** — assistir partidas anteriores
- [ ] **Espectador** — assistir partida em andamento
- [ ] **Rankings e leaderboard**
- [ ] **Mobile** — exportação para Android/iOS

---

## 3. HERÓIS — STATUS E ARTE

### Tabela de Heróis

| Herói | Classe | HP | Atk | Def | Arte | Habilidade Ativa | Habilidade Passiva |
|-------|--------|:--:|:---:|:---:|:----:|-----------------|-------------------|
| **Poppy** | Bárbara | 10 | 2 | 1 | ✅ | *Impacto Sísmico* — Cadeia [Terra·Fogo·Fogo] → +3 ATK | *Ataque Descuidado* — se nenhuma carta de defesa na rodada, +1 ATK |
| **Irena** | Clérigo | 9 | 0 | 2 | ✅ | *Toque Revigorante* — Cadeia [Água·Água·Terra] → curas ganham +1 até fim do turno | *Crescimento Natural* — fim de turno cura todos os aliados em 1 |
| **Hakai** | Ladino | 10 | 1 | 0 | ✅ | *Instinto de Caça* — Cadeia [Ar·Ar·Ar] → torna-se furtivo | *Golpe das Sombras* — +1 ATK permanente ao causar dano enquanto furtivo |
| **Ieldor** | Arqueiro | 9 | 1 | -1 | ✅ | *Chuva de Flechas* — Cadeia [Fogo·Ar·Ar] → 1 dano a todos heróis inimigos | *Retaguarda Precisa* — escolhe 1 herói inimigo por rodada e causa 1 dano direto |
| **Nissin** | Monge | 10 | 1 | 2 | ❌ | *Passos Ágeis* — Cadeia [Ar·Ar·Água] → compra 1 carta (1x por turno) | *Fluxo Suave* — jogou ACTION + BONUS_ACTION na mesma rodada → +1 ATK |
| **Valkar** | Guardião | 10 | 0 | 3 | ✅ | *Escudo de Espinhos* — Cadeia [Terra·Terra·Água] → bônus ATK = metade da defesa base | *Muro de Aço* — primeiro dano a aliado por turno reduzido em 1 (passiva de retaguarda) |

**Arte disponível:** 5 de 6 heróis (Nissin sem arte finalizada)

### Detalhamento das Habilidades de Retaguarda

| Herói | Tipo | Funcionamento |
|-------|------|---------------|
| **Ieldor** | Interativa (fase BACKLINE_ABILITY) | Antes da fase ACTION, Ieldor escolhe 1 herói inimigo e causa 1 de dano direto |
| **Irena** | Passiva automática | Ao fim de cada turno, cura 1 de HP de todos os aliados vivos |

### Detalhamento das Habilidades de Front
| Herói | Tipo | Funcionamento |
|-------|------|---------------|
| **Valkar** | Passiva automática | Quando qualquer aliado for atacado, o primeiro dano do turno é reduzido em 1 |
---

## 4. CATÁLOGO COMPLETO DE CARTAS

> **Legenda:** ✅ Arte pronta · ❌ Arte pendente (usa placeholder)  
> **Símbolos:** 🔥 Fogo · 🌍 Terra · 💧 Água · 🌀 Ar  

### ACTIONS — Common (26 cartas)

| ID | Nome | Atk | Def | Símbolo | Furtivo | Arte | Efeito |
|:--:|------|:---:|:---:|:-------:|:-------:|:----:|--------|
| 1 | Golpe Bruto | 4 | 0 | 🔥 | — | ✅ | — |
| 2 | Perfeito Equilíbrio | 2 | 2 | 🌍 | — | ✅ | — |
| 3 | Corte Preciso | 3 | 1 | 🌀 | — | ✅ | — |
| 4 | Postura Firme | 1 | 3 | 🌍 | — | ✅ | — |
| 5 | Avanço Imprudente | 5 | -1 | 🔥 | — | ✅ | — |
| 6 | Investida Selvagem | 6 | -2 | 🔥 | — | ✅ | — |
| 7 | Exposição Tática | 4 | -2 | 🌀 | — | ✅ | — |
| 8 | Defesa Implacável | 0 | 4 | 🌍 | — | ✅ | — |
| 9 | Impacto Controlado | 2 | 1 | 🌍 | — | ✅ | Se bloqueio total: compra 1 |
| 10 | Chama Crescente | 2 | 1 | 🔥 | — | ❌ | Se jogou 🔥 neste turno: +1 ATK |
| 11 | Pressão Inicial | 3 | 0 | 🌀 | — | ❌ | Se 1ª carta do turno: +1 DEF |
| 12 | Encadeamento | 2 | 1 | 🌍 | — | ❌ | Se 3ª carta do turno: compra 1 |
| 13 | Impulso Ofensivo | 1 | 1 | 🔥 | — | ❌ | Próxima carta: +2 ATK |
| 14 | Pequenos Riscos | 1 | 0 | 🌍 | — | ❌ | Descarte 1, compre 1 |
| 15 | Corrente | 1 | 2 | 🌀 | — | ❌ | Compre 1, descarte 1 |
| 16 | Movimento Preciso | 3 | 0 | 🌀 | — | ❌ | Se jogou BONUS_ACTION neste turno: +1 DEF |
| 17 | Brisa Cortante | 2 | 1 | 🌀 | — | ❌ | Se veio do arsenal: +1 ATK |
| 18 | Fluxo Sereno | 0 | 3 | 💧 | — | ❌ | Se bloqueio total: cura 1 |
| 19 | Corrente Restauradora | 1 | 2 | 💧 | — | ❌ | Cura 1 do herói ativo |
| 20 | Onda Reversa | 3 | 1 | 💧 | — | ❌ | Pode colocar esta carta no fundo do deck |
| 21 | Reflexo Líquido | 1 | 2 | 💧 | — | ❌ | Compre 1, descarte 1 |
| 22 | Renovação | 1 | 1 | 💧 | — | ❌ | Se sua vida < oponente: cura 2 |
| 23 | Passo Fantasma | 2 | 1 | 🌀 | ✅ | ❌ | Herói permanece oculto |
| 24 | Resistência Natural | 1 | 2 | 💧 | — | ❌ | No final do combate: cura 1 |
| 25 | Fúria Instável | 6 | -1 | 🔥 | — | ❌ | Se causar dano: descarta 1 |
| 26 | Linha de Ferro | 0 | 3 | 🌍 | — | ❌ | Próxima carta neste combate: +1 ATK |

### BONUS ACTIONS — Common (12 cartas)

| ID | Nome | Atk | Def | Símbolo | Arte | Efeito |
|:--:|------|:---:|:---:|:-------:|:----:|--------|
| 27 | Passo Leve | 0 | 1 | 🌀 | ❌ | — |
| 28 | Chama Instável | 1 | 0 | 🔥 | ❌ | — |
| 29 | Ajuste Fino | 0 | 0 | 🌍 | ✅ | Compre 1, descarte 1 |
| 30 | Ajuste de Guarda | 0 | 1 | 🌍 | ❌ | Se 1ª carta do combate: +1 ATK |
| 31 | Impulso Rápido | 1 | 0 | 🌀 | ❌ | Se jogou ACTION neste combate: +1 DEF |
| 32 | Respiração Serena | 0 | 0 | 💧 | ❌ | Cura 1 |
| 33 | Brisa Ardente | 3 | -1 | 🔥 | ❌ | — |
| 34 | Guarda Breve | -1 | 2 | 🌍 | ❌ | — |
| 35 | Fluxo Ágil | 1 | 0 | 🌀 | ❌ | Se veio do arsenal: compre 1, descarte 1 |
| 36 | Brasa | 2 | 0 | 🔥 | ❌ | — |
| 37 | Ritmo | 0 | 1 | 🌀 | ❌ | Se jogou ACTION neste combate: compre 1, descarte 1 |
| 38 | Versatilidade | 0 | 0 | — | ❌ | Escolha o elemento desta carta |

### REACTIONS — Common (8 cartas)

| ID | Nome | Atk | Def | Símbolo | Arte | Efeito |
|:--:|------|:---:|:---:|:-------:|:----:|--------|
| 39 | Bloqueio Instintivo | 0 | 1 | 🌍 | ❌ | — |
| 40 | Desvio Rápido | 0 | 0 | 🌀 | ❌ | Descarte 2, compre 1 |
| 41 | Guarda Emergencial | -1 | 2 | 🌍 | ❌ | — |
| 42 | Reflexivo Ofensivo | 1 | 0 | 🔥 | ❌ | — |
| 43 | Passo Nebuloso | 0 | 1 | 🌀 | ❌ | — |
| 44 | Recuperação Breve | 0 | 0 | 💧 | ❌ | Cura 1 |
| 45 | Maré Suave | 0 | 1 | 💧 | ❌ | Se não tomar dano: cura 1 |
| 46 | Instinto Violento | 2 | -1 | 🔥 | ❌ | — |

### ACTIONS — Rare (12 cartas)

| ID | Nome | Atk | Def | Símbolo | Arte | Efeito |
|:--:|------|:---:|:---:|:-------:|:----:|--------|
| 47 | Solo Firme | 0 | 3 | 🌍 | ❌ | Se bloqueio total: compre 1, descarte 1 |
| 48 | Corrente Ascendente | 2 | 1 | 💧 | ❌ | Cura 1 |
| 49 | Pressão Contínua | 2 | 0 | 🔥 | ❌ | Próxima carta: +1 ATK e +1 DEF |
| 50 | Passo Estratégico | 1 | 2 | 🌀 | ❌ | Coloque uma carta da mão no arsenal |
| 51 | Ritmo Calculado | 1 | 1 | 🌀 | ❌ | Se 2ª carta do combate: compre 1 |
| 52 | Sacrifício | 0 | -3 | 🌍 | ❌ | Compre 1 carta |
| 53 | Golpe Furtivo | 3 | 0 | 🌀 | ✅ | Furtivo — herói permanece oculto |
| 54 | Tim | 0 | 4 | 🌍 | ❌ | Se sua vida < oponente: +1 DEF |
| 55 | Coração da Fornalha | 3 | 0 | 🔥 | ✅ | +1 ATK por símbolo 🔥 jogado neste turno |
| 56 | Sombra Oculta | 2 | 0 | 🌀 | ❌ | Se herói oculto: +2 ATK |
| 57 | Broto Vital | 1 | 2 | 💧 | ❌ | Cura 1 num herói aliado à sua escolha |
| 58 | Tiro de Oportunidade | 2 | 1 | 🌀 | ❌ | Se 1ª carta do combate: 1 dano direto |

### BONUS ACTIONS — Rare (7 cartas)

| ID | Nome | Atk | Def | Símbolo | Arte | Efeito |
|:--:|------|:---:|:---:|:-------:|:----:|--------|
| 59 | Estopim | 1 | 0 | 🔥 | ❌ | Descarte 1: +2 ATK |
| 60 | Reorganizar | 0 | 0 | 🌍 | ❌ | Coloque uma carta da mão no fundo; compre 1 |
| 61 | Eco Ardente | 2 | 0 | 🔥 | ❌ | Se 2ª carta do combate: +1 ATK |
| 62 | Respiração Profunda | 0 | 1 | 💧 | ❌ | Recicle uma carta do cemitério no fundo do deck |
| 63 | Dois Passos à Frente | 0 | 1 | 🌀 | ❌ | Scry 1 — veja o topo do deck, deixe ou mande pro fundo |
| 64 | Véu Transitório | 0 | 1 | 🌀 | ❌ | Se veio do arsenal: herói permanece oculto |
| 65 | Preparando o Arsenal | 0 | 1 | 🌍 | ❌ | Coloque uma carta da mão no arsenal |

### REACTIONS — Rare (7 cartas)

| ID | Nome | Atk | Def | Símbolo | Arte | Efeito |
|:--:|------|:---:|:---:|:-------:|:----:|--------|
| 66 | Finta | 0 | 1 | 🌍 | ✅ | Próxima carta do oponente perde 1 ATK |
| 67 | Sangue Quente | 1 | 0 | 🔥 | ❌ | Se herói já sofreu dano neste combate: +1 ATK |
| 68 | Iniciando na Magia | 0 | 0 | — | ❌ | Escolha o elemento desta carta |
| 69 | Simples | 1 | 1 | 🌀 | ❌ | — |
| 70 | Fluxo Defensivo | 0 | 1 | 🌀 | ❌ | Se jogou BONUS_ACTION neste combate: +1 ATK e +1 DEF |
| 71 | Guarda Inabalável | 0 | 2 | 🌍 | ❌ | Se não tomar dano: +1 ATK no próximo combate |
| 72 | Fluxo Reativo | 0 | 1 | 💧 | ❌ | Previna 1 de dano até fim do turno |

### ACTIONS — Legendary (6 cartas)

| ID | Nome | Atk | Def | Símbolo | Arte | Efeito |
|:--:|------|:---:|:---:|:-------:|:----:|--------|
| 73 | Sintonia Primordial | 1 | 1 | — | ❌ | Escolha o símbolo. Se ativar habilidade do herói: compre 1 |
| 74 | Quebrando a Banca | 3 | 0 | 🌍 | ✅ | Se causar dano: destrua o arsenal inimigo |
| 75 | Frenesi | 4 | -3 | 🔥 | ❌ | Se defesa atual < defesa base: +1 ATK até fim do turno |
| 76 | Execução Silenciosa | 3 | -1 | 🌀 | ❌ | Se furtivo até o combate: +1 ATK. Se causar dano: próximo combate começa furtivo |
| 77 | Florescer Eterno | 1 | 1 | 💧 | ❌ | Cura 1 e toda cura do turno afeta todos os aliados |
| 78 | Fluxo Perfeito | 2 | 1 | 🌀 | ❌ | Se 3ª carta do combate: compre 1 |

### BONUS ACTIONS — Legendary (3 cartas)

| ID | Nome | Atk | Def | Símbolo | Arte | Efeito |
|:--:|------|:---:|:---:|:-------:|:----:|--------|
| 79 | Planos Futuros | 0 | 0 | 🌍 | ✅ | Tutor — escolha qualquer carta do deck e coloque na mão |
| 80 | Ricochetear | 1 | 0 | 🌀 | ❌ | Dano ao herói ativo inimigo também causa 1 dano a outro herói aleatório |
| 81 | Fortaleza Inabalável | 0 | 1 | 🌍 | ❌ | Herói ativo recebe +1 ATK sempre que aumentar defesa (até fim do combate) |

### REACTIONS — Legendary (3 cartas)

| ID | Nome | Atk | Def | Símbolo | Arte | Efeito |
|:--:|------|:---:|:---:|:-------:|:----:|--------|
| 82 | Manipulando Elementos | 0 | 0 | — | ✅ | Escolha 2 elementos para esta carta |
| 83 | Ecos do Passado | 0 | 1 | 🌍 | ❌ | Ambos os jogadores escolhem uma carta do cemitério para o arsenal |
| 84 | Ciclo Vital | 0 | 1 | 💧 | ❌ | Cura 2. Se finalizar com vida cheia: retorna à mão |

---

### Resumo de Arte por Categoria

| Categoria | Total | Com Arte | Sem Arte |
|-----------|:-----:|:--------:|:--------:|
| ACTION Common | 26 | 2 | 24 |
| BONUS_ACTION Common | 12 | 1 | 11 |
| REACTION Common | 8 | 0 | 8 |
| ACTION Rare | 12 | 2 | 10 |
| BONUS_ACTION Rare | 7 | 0 | 7 |
| REACTION Rare | 7 | 1 | 6 |
| ACTION Legendary | 6 | 1 | 5 |
| BONUS_ACTION Legendary | 3 | 1 | 2 |
| REACTION Legendary | 3 | 1 | 2 |
| **TOTAL** | **84** | **9** | **75** |

> **9 de 84 cartas** têm arte finalizada.  
> Todas as demais exibem o placeholder no jogo.

---

## 5. COMO JOGAR (HOW TO PLAY)

### Objetivo

Eliminar todos os 3 heróis do oponente reduzindo o HP de cada um a 0.  
Cada jogador começa com um time de 3 heróis e um deck de cartas.

---

### Preparação da Partida

1. **Conexão:** Um jogador faz o host e o outro se conecta pelo IP na tela de lobby.
2. **Deck:** Cada jogador envia o deck montado no Deck Builder (até 300 cartas, máx 3 cópias por carta).
3. **Embaralhamento:** O deck é embaralhado automaticamente.
4. **Compra inicial:** Cada jogador compra 6 cartas.

---

### Fase 1 — Mulligan de Abertura (`OPENING_MULLIGAN`)

> "Você pode ajustar sua mão inicial antes da partida começar."

- Cada jogador deve devolver **exatamente 2 cartas** ao fundo do deck.
- Após devolver, compra novas cartas até ter 6 na mão.
- Ambos os jogadores fazem isso simultaneamente.
- Após ambos confirmarem, a partida começa.

---

### Estrutura de um Turno

Um turno completo passa pelas seguintes fases, nesta ordem:

```
DRAW → HERO_SELECTION → BACKLINE_ABILITY → ACTION (múltiplas rodadas) → COMBAT → END
```

---

### Fase 2 — Compra (`DRAW`)

O jogador ativo compra cartas até ter 4 na mão (se tiver menos de 4). Se já tiver 4 ou mais, não compra nada.  
Cartas excedentes a 6 vão automaticamente ao fundo do deck.

---

### Fase 3 — Seleção de Herói (`HERO_SELECTION`)

> "Quem você vai mandar pra linha de frente?"

- Ambos os jogadores escolhem simultaneamente **1 herói** do seu time para ser o herói ativo.
- A escolha é **face-down** — o oponente não vê qual herói foi escolhido.
- Heróis **exaustos** (que já combateram neste ciclo) não podem ser escolhidos.
- Se todos os heróis estiverem exaustos, todos são restaurados antes da seleção.

---

### Fase 4 — Habilidade de Retaguarda (`BACKLINE_ABILITY`)

> "Heróis que não estão na frente ainda podem agir."

- Heróis com habilidade de retaguarda interativa (atualmente **Ieldor**) agem nesta fase.
- **Ieldor** escolhe 1 herói inimigo e causa **1 de dano direto** antes do combate começar.
- O jogador cujo herói possui a habilidade decide se usa ou passa (pode optar por não usar).

---

### Fase 5 — Ação (`ACTION`)

Esta é a fase principal do combate. É dividida em **rodadas**, e cada rodada tem **2 segmentos** (um por jogador).

#### Sequência de um Segmento

```
Jogador A age → Janela de Reação para B → Jogador A joga BONUS_ACTION → Passa a vez para B
```

**Passo a passo:**

1. **Jogador ativo** pode jogar **1 carta ACTION** da mão ou do arsenal.
   - Se a carta não for furtiva (`is_stealth = false`), o **herói é revelado** ao oponente.
   - Os efeitos "pré-janela" da carta são resolvidos imediatamente.

2. **Janela de Reação** se abre para o oponente:
   - O oponente pode jogar **1 carta REACTION** (fecha a janela).
   - O oponente pode **passar** (fecha a janela sem jogar nada).
   - Se o atacante tem `pending_cancel_reaction = true`, a janela **não abre**.

3. Os efeitos pós-reação da carta ACTION são resolvidos.

4. O jogador ativo pode jogar **1 carta BONUS_ACTION** (não abre janela de reação).

5. O segmento encerra e a vez passa para o outro jogador.

#### Fim de uma Rodada

Após ambos os jogadores completarem seus segmentos, o **combate resolve** (ver Fase 6).

#### Fim da Fase ACTION

A fase ACTION termina quando:
- **2 rodadas consecutivas** sem nenhuma ACTION jogada (ambos passaram), **OU**
- Ambos os jogadores estão **sem cartas na mão**.

---

### Fase 6 — Resolução de Combate (`COMBAT`)

> "Os danos são calculados e aplicados."

A resolução acontece automaticamente ao fim de cada rodada.

#### Fórmula de Dano

```
Ataque Total = Ataque Base do Herói
             + Soma dos attack_value das cartas jogadas na rodada
             + Bônus de ataque pendentes
             - Penalidades do oponente (ex: Finta)

Defesa Total = Defesa Base do Herói
             + Soma dos defense_value das cartas jogadas na rodada
             + Bônus de defesa pendentes

Dano Bruto   = max(0,  Ataque Total - Defesa Total)
Dano Final   = max(0,  Dano Bruto - Escudo de Dano)
             → Hooks do herói defensor podem reduzir o dano (ex: Valkar)
```

#### Efeitos Especiais no Combate

| Situação | Resultado |
|----------|-----------|
| Dano final = 0 | Bloqueio total! Efeitos de "full block" ativam (ex: comprar, curar) |
| Dano final > 0 e possui *Quebrando a Banca* | Arsenal do oponente é destruído |
| Possui *Ricochetear* | Dano ao herói ativo também atinge outro herói inimigo aleatório |
| Possui *Reflexo Reativo* | 1 de dano é absorvido como escudo |
| Herói derrotado (HP = 0) | Herói eliminado; jogo verifica se a partida acabou |

Todos os heróis ocultos que ainda não foram revelados são **forçadamente revelados** no início do combate.

---

### Fase 7 — Fim de Turno (`END`)

1. O jogador ativo **pode guardar 1 carta** da mão no **Arsenal** (área especial face-up visível a ambos).
   - Se já havia uma carta no arsenal, a anterior vai ao fundo do deck.
   - O jogador pode optar por não guardar nenhuma carta (passar -1).

2. O herói ativo é marcado como **exausto** (não pode ser escolhido até todos estarem exaustos).

3. O jogador compra cartas até ter **4 na mão**.

4. O turno passa para o adversário (que agora é o "jogador ativo").

---

### O Arsenal

O arsenal é um slot especial de **1 carta** para cada jogador:

- A carta no arsenal fica **face-up** (visível para ambos).
- Pode ser jogada como **ACTION, BONUS_ACTION ou REACTION**, seguindo as mesmas regras de timing.
- Algumas cartas têm efeitos especiais quando jogadas **do arsenal** (ex: *Brisa Cortante* ganha +1 ATK; *Véu Transitório* mantém o herói oculto).

---

### Sistema de Símbolos e Habilidades Ativas

Cada carta possui um ou mais **símbolos elementais**:

| Símbolo | Elemento |
|:-------:|---------|
| 🔥 | Fogo |
| 🌍 | Terra |
| 💧 | Água |
| 🌀 | Ar |

As cartas jogadas formam uma **cadeia de símbolos acumulada** no turno. Quando a cadeia contém a **subsequência exata** exigida pelo herói ativo (máximo 3 símbolos), a **habilidade ativa** do herói dispara automaticamente.

**Exemplo:** Poppy precisa da cadeia [Terra·Fogo·Fogo]. Se você jogar *Postura Firme* (Terra) e depois *Chama Crescente* (Fogo) e *Fúria Instável* (Fogo) em qualquer ponto do turno, a habilidade *Impacto Sísmico* de Poppy ativa, concedendo +3 ATK.

> Algumas cartas como *Sintonia Primordial*, *Versatilidade* e *Manipulando Elementos* permitem **escolher** qual símbolo adicionar à cadeia — use para ativar habilidades com mais facilidade.

---

### O Blefe do Herói Oculto

O herói ativo começa sempre **oculto** ao oponente. O oponente só descobre qual herói está na frente quando:

1. Você joga uma carta ACTION **não-furtiva** (a maioria das cartas).
2. Você joga uma carta do arsenal **não-furtiva**.
3. O combate começa (todos revelados à força).
4. O turno termina.

**Cartas furtivas** (`Passo Fantasma`, `Golpe Furtivo`, `Véu Transitório`, etc.) permitem atacar sem revelar o herói, mantendo o blefe.

**Por que isso importa?** O oponente não sabe se precisa bloquear um Poppy (alto ATK) ou um Valkar (alto DEF) até você revelar — ou ser forçado pelo combate.

---

### Fim de Jogo

A partida termina quando **todos os 3 heróis** de um jogador chegam a **HP = 0**.  
O jogador que ainda tem heróis vivos vence.

---

## 6. PLANEJAMENTO PARA O ALPHA

### Definição de Alpha

> Um Alpha funcional é: **2 jogadores conseguem jogar uma partida completa via LAN sem bugs críticos, usando decks montados por eles, com experiência mínima de onboarding.**

---

### Milestones do Alpha

#### Milestone 1 — Deck Builder ✅ Concluído

O Deck Builder está completamente implementado e integrado no lobby. Inclui:
- `card_picker`, `deck_rail`, `hero_picker`, `picker_panel`, `cosmetics_panel`
- Filtros de carta, validação em tempo real (máx 3 cópias, máx 300 cartas)
- Persistência via `DeckStore`, nomes personalizados por deck
- Botão direto no lobby para abrir antes de iniciar partida

---

#### Milestone 2 — Arte Mínima Viável (Prioridade Alta)

**Objetivo:** Todas as cartas têm arte identificável (não precisa ser final).

Tarefas:
- [ ] Arte para os 84 cards (pode ser sketch/conceitual para o alpha)
- [ ] Arte finalizada para Nissin
- [ ] Revisão de consistência visual dos heróis existentes

**Prioridade de arte das cartas (ordem sugerida):**
1. Lendárias (12 cartas) — têm mais impacto visual
2. Rares de maior impacto (Golpe Furtivo, Sombra Oculta, Sacrifício)
3. Commons mais jogadas (Golpe Bruto, Perfeito Equilíbrio, Passo Fantasma)

**Estimativa:** Depende da equipe de arte; código pronto.

---

#### Milestone 3 — Estabilidade e Polimento (Prioridade Alta)

**Objetivo:** Partida sem bugs críticos e com feedback visual claro.

Tarefas:
- [ ] Revisar todos os efeitos Legendary em partidas reais (Ciclo Vital, Ecos do Passado, Ricochetear)
- [ ] Melhorar indicadores de fase — HUD claro mostrando: fase atual, turno de quem é, heróis exaustos
- [ ] Tela de derrota/vitória com estatísticas básicas da partida (dano causado, cartas jogadas)
- [ ] Corrigir qualquer dessincronização de rede identificada em testes
- [ ] Feedback sonoro mínimo: 5–8 SFX críticos (jogar carta, dano, bloquear, habilidade, comprar)
- [ ] Teste de balanceamento: jogar 20+ partidas e registrar heróis/cartas dominantes

**Estimativa:** 2–3 semanas

---

#### Milestone 4 — Onboarding (Prioridade Média)

**Objetivo:** Um jogador novo consegue aprender o jogo sem ajuda externa.

Tarefas:
- [ ] Tooltips em cards e heróis com descrição do efeito
- [ ] Tutorial interativo: partida guiada com dicas passo a passo (pode ser vs IA simples)
- [ ] Tela "Como Jogar" acessível no menu principal (baseada nesta documentação)
- [ ] Log de ações na tela: histórico do que aconteceu na rodada atual

**Estimativa:** 1–2 semanas

---

#### Milestone 5 — Infraestrutura de Alpha (Prioridade Média)

**Objetivo:** Suporte a múltiplas sessões simultâneas e feedback de usuários.

Tarefas:
- [ ] Build exportável para Windows (`.exe`) para distribuir
- [ ] Tela de perfil: nome do jogador, avatar básico
- [ ] Relatório de bugs in-game (F12 ou menu → "Reportar Bug")
- [ ] Versão do jogo exibida na tela principal
- [ ] Modo offline para testar decks contra IA básica (bot aleatório)

**Estimativa:** 1 semana

---

### Cronograma Sugerido para Alpha

| Semana | Foco |
|--------|------|
| 1–2 | Deck Builder (base funcional) |
| 3 | Deck Builder (filtros, validação, integração no lobby) |
| 4–5 | Estabilidade: testes em partida real, correção de bugs |
| 6 | Onboarding: tooltips + tela "Como Jogar" |
| 7 | Build exportável + ajustes finais |
| 8 | **Alpha Release** — distribuição para grupo de teste |

> Arte das cartas pode correr em paralelo com qualquer semana.

---

## 7. PRÓXIMOS PASSOS DETALHADOS

### Eixo 1 — Jogabilidade e Balanceamento

#### 1.1 Sistema de Balanceamento Contínuo
- Implementar **log estruturado de partidas**: registrar em JSON cada carta jogada, herói escolhido, dano causado/recebido, e resultado.
- Criar **dashboard de balanceamento** (pode ser externo — Python + matplotlib ou similar) que lê os logs e mostra win rate por herói, taxa de uso de cartas, dano médio por card.
- Definir **métricas de equilíbrio alvo:** nenhum herói com win rate > 60%; nenhuma carta em > 80% dos decks vencedores.

#### 1.2 Novos Heróis (Pós-Alpha)
Diretrizes para expansão:
- Cada novo herói deve ter mecânica distinta dos 6 atuais
- Sugestões de arquétipos ausentes:
  - **Necromante** — mecânica de cemitério (revive cartas)
  - **Druida** — sinergia com múltiplos elementos na mesma rodada
  - **Espadachim** — mecânica de "stance" (postura ofensiva vs defensiva alternada)
  - **Alquimista** — cria cartas temporárias durante a partida

#### 1.3 Segundo Set de Cartas
- **24 novas cartas** (proporção: 14 Common, 7 Rare, 3 Legendary) para um total de 108
- Focar em sinergia com os novos heróis
- Introduzir mecânica nova: **cartas com custo** (gastar HP para jogar)

---

### Eixo 2 — Infraestrutura Online

#### 2.1 Migração para Servidor Dedicado (Relay)
- Atualmente o jogo é **exclusivamente LAN**. Para escalar, precisamos de relay ou servidor dedicado.
- Opções:
  - **Steam Networking** (via GodotSteam plugin) — melhor para distribuição futura na Steam
  - **Nakama** (servidor open source) — mais flexível, suporta ranking e matchmaking
  - **Relay simples** (VPS + ENet bridge) — mais rápido de implementar, sem matchmaking

#### 2.2 Matchmaking
- Fila de matchmaking por elo (sistema Elo simplificado)
- Sala privada com código (equivalente ao LAN atual, mas online)
- Modo espectador (peer adicional recebe o estado mas não envia ações)

#### 2.3 Persistência de Conta
- Backend mínimo: autenticação (email/senha ou OAuth com Google)
- Armazenar coleção, decks e histórico de partidas na nuvem
- Sincronização entre sessões (jogar no PC, continuar no notebook)

---

### Eixo 3 — Conteúdo e Progressão

#### 3.1 Sistema de Progressão
- **Pacotes de cartas** — abrir packs de 5 cartas (1 garantida Rare ou melhor)
- **Moeda do jogo** — ganhar por partidas completadas (vitória + derrota)
- **Missões diárias** — "Cause 20 de dano com Fogo", "Vença uma partida usando Hakai"
- **Desafios de coleção** — desbloquear cosméticos ao completar sets de cartas

#### 3.2 Cosméticos
- Mais **playmats** (já existe estrutura de CosmeticsStore)
- **Sleeves** — verso das cartas customizável (já existe estrutura)
- **Avatar de herói** — versões alternativas dos heróis (ex: Poppy jovem, Hakai mascarado)
- **Animações de habilidade** — VFX exclusivos por skin de herói

#### 3.3 Modo Solo
- **Modo Campanha** — série de batalhas com narrativa e dificuldade crescente
- **Desafios Táticos** — puzzles com condição específica ("Vença esta batalha em 1 turno com as cartas X, Y, Z")
- **IA com Personalidades** — bots que representam cada herói com playstyle característico

---

### Eixo 4 — Plataforma e Distribuição

#### 4.1 Distribuição PC
- **Build Windows** — exportação `.exe` para testes internos (Milestone 5)
- **Steam** — publicação na Early Access após alpha estabilizado
  - Requisitos: página da loja, screenshots, trailer, EULA
  - Integração GodotSteam para achievements e leaderboard

#### 4.2 Mobile (Longo Prazo)
- Godot 4 exporta para Android/iOS nativamente
- Adaptações necessárias: interface touch, tamanho de elementos, drag simplificado
- Partidas assíncronas (jogar sem precisar dos dois jogadores online ao mesmo tempo)

#### 4.3 Web
- Godot 4 exporta para HTML5 via WebAssembly
- Jogável no browser sem instalação — ideal para onboarding de novos jogadores
- Limitação: não tem acesso a ENet nativo, precisaria migrar para WebRTC

---

### Eixo 5 — Qualidade e DevOps

#### 5.1 Testes Automatizados
- GUT (Godot Unit Testing) para lógica core
- Testes prioritários: `CombatResolver`, `SymbolChain`, `CardEffectRegistry`, `TurnManager`
- CI simples: rodar testes a cada push via GitHub Actions

#### 5.2 Ferramentas de Dev
- **Sandbox Mode** — iniciar partida em estado pré-definido para testar interações específicas
- **Debug Overlay** — exibir estado interno do GameState em overlay togglável (F1)
- **Cartas de debug** — cartas especiais para forçar situações específicas em teste

#### 5.3 Documentação Técnica
- Manter `CLAUDE.md` atualizado com cada novo sistema
- Documentar API de cada herói para facilitar contribuições futuras
- Guia de criação de carta (passo a passo: JSON → effect → arte → teste)

---

### Roadmap Visual

```
2026
Mai–Jun   ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░  Alpha Interno
          [Deck Builder] [Estabilidade] [Arte mínima]

Jul–Ago   ░░░░░░░░▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░  Alpha Público
          [Onboarding] [Build exportável] [Testes externos]

Set–Out   ░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓░░░░░░░░░░░  Beta
          [Online relay] [Novos heróis] [Progressão]

Nov–Dez   ░░░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓░░░  Early Access
          [Steam] [Matchmaking] [Segundo set]
```

---

*Documentação gerada em Maio de 2026. Para reportar inconsistências ou sugerir atualizações, editar diretamente neste documento.*
