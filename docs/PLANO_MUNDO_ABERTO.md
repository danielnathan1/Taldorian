# Plano — Mundo Aberto (Onboarding + Scanner + Missões)

> Documento de planejamento. Descreve a **arquitetura e o roadmap** para a primeira camada
> jogável do mundo aberto: abertura cinematográfica, primeira missão guiada, mecânica do
> "scam mágico" (scanner) e o framework de missões/minigames.
> Fonte de verdade do *plano* — o código é a fonte de verdade da *implementação*.

---

## 0. Decisões-chave (já fechadas)

1. **Onboarding é uma FASE INSTANCIADA (solo), mas o jogador está LOGADO E ONLINE.**
   O jogador autentica normalmente (`ApiClient`) e está conectado — o onboarding **não** é offline
   nem sem conta. O que o torna "local" é que **não há outro jogador nem estado de mundo
   compartilhado pra sincronizar**: é uma instância só dele, como uma fase solo em outros jogos.
   Por isso, o passo-a-passo do tutorial (cutscene, detecção do scanner, scan do slime) roda
   **client-side**, sem `WorldState`/sync de posição e sem o servidor dedicado arbitrando cada
   ação via RPC. Isso desacopla a parte criativa da camada de sync multiplayer.
   - **Persistência da recompensa é autoritativa:** o *grant* da carta/cosmético do tutorial deve
     passar pelo backend (ex.: endpoint "concluir tutorial" que concede a recompensa), não ser
     confiado 100% no cliente. Risco baixo no slime inicial, mas é o hábito correto (jogador está online).
   - O servidor dedicado / `WorldState` entram quando o jogador "entra de verdade" no mundo
     compartilhado (a taverna / outros jogadores).

2. **Recompensa de scan é polimórfica (`ScanReward`).** Um scan pode dar:
   - uma **carta jogável** (entra no pool do TCG via `Collection`),
   - um **cosmético** (sleeve/playmat via `CosmeticsStore`),
   - um **item visual** (decoração de personagem / troféu — categoria nova).
   Não existe "scan = carta". Existe "scan = recompensa", e a recompensa tem tipo.

3. **Tudo data-driven.** Diálogos, scannables, missões e tabelas de recompensa vivem em JSON.
   As cenas reagem e exibem — nunca decidem (mesma regra do TCG).

---

## 1. Separação: Onboarding Local × Mundo Real

```
character_creator  ──►  ONBOARDING (fase instanciada, solo)  ──►  MUNDO REAL (mundo compartilhado)
   [logado/online]         jogador LOGADO e ONLINE                  • WorldState / RPC (sync)
                           • abertura cinematográfica               • outros jogadores
                           • missão 1 (encapuzado)                  • salas / fila / trocas
                           • tutorial do scanner
                           • 1º scan (slime) → grant autoritativo (backend)
                           gate: flag "tutorial_done"
```

- **O jogador está autenticado e conectado o tempo todo** — o onboarding é uma instância solo,
  não um modo offline. Só não há sync de mundo porque não há ninguém mais na instância.
- Ponto de inserção: **entre a criação de personagem e a primeira entrada no mundo compartilhado.**
- Gate persistido (`tutorial_done`): no perfil do backend (`/players/me`) e/ou cache `user://`.
  Se já completou, pula direto pro mundo compartilhado.
- A cena de onboarding reusa o `player_character` visual, mas no lugar do sync de rede usa um
  **`OnboardingController` local** que dirige a cutscene, libera input e dispara o tutorial.
- A **recompensa** do tutorial é concedida por caminho autoritativo (backend), mesmo a lógica
  da fase sendo client-side.

> Benefício: dá pra construir e iterar a missão 1 inteira sem depender do sync multiplayer do
> servidor dedicado — mantendo o jogador online e a recompensa persistida na conta.

---

## 2. Modelo de Recompensa — `ScanReward`

`RefCounted` puro (sem node, sem UI), no espírito de `src/entities/`.

```gdscript
# src/world/scan_reward.gd  (esboço)
enum Kind { CARD, COSMETIC, VISUAL_ITEM }

var kind: Kind
var ref_id: String      # card_id | cosmetic_id | item_id
var amount: int = 1

func grant() -> void:
    match kind:
        Kind.CARD:        Collection.add_card(ref_id, amount)
        Kind.COSMETIC:    CosmeticsStore.unlock(ref_id)
        Kind.VISUAL_ITEM: # categoria nova — ver §2.1
```

### 2.1 Itens visuais (categoria nova)
- Decisão pendente: onde persistir (`/players/me/inventory` já carrega heróis/cartas/playmats;
  itens visuais podem entrar como um novo `kind` no inventário do backend).
- Começar **client-side em `user://`** como placeholder; migrar pro backend quando o serviço real existir.

### 2.2 Tabela de loot por scannable
- Cada `Scannable` aponta para uma **tabela de recompensa** (pode ser determinística no tutorial:
  slime → sempre a carta de slime). Tabelas probabilísticas vêm depois.

---

## 3. Os 6 Sistemas-Base (reusáveis — construir antes das missões)

### 3.1 Sistema de Diálogo (Stardew-style)
- **Cena:** `scenes/world/ui/dialogue/dialogue_box.tscn` (+ `.gd`). Layout montado **no `.tscn`**
  (caixa inferior-central, retrato à esquerda, nome do falante, indicador de "avançar").
- **Dados:** `data/dialogues/*.json`
  ```json
  {
    "id": "intro_encapuzado",
    "lines": [
      { "speaker": "???",        "portrait": "encapuzado", "text": "..." },
      { "speaker": "Encapuzado", "portrait": "encapuzado", "text": "..." }
    ]
  }
  ```
  Linear primeiro; ramificação (`choices`) depois.
- **Sinais (GameBus):** `dialogue_started(id)`, `dialogue_advanced(idx)`, `dialogue_finished(id)`.
- Input do jogador travado enquanto o diálogo está aberto.
- **Reusado por:** todo NPC, toda missão.

### 3.2 Sequenciador de Cutscene
- Dirige sequências scriptadas: "personagem anda → para → NPC se aproxima → diálogo →
  item aparece no centro → libera movimento".
- **Abordagem:** script de passos com `await` (legível para narrativa). `AnimationPlayer`
  para os movimentos finos (tween de posição, fade do item).
- Trava/destrava input do player; emite marcos para a missão avançar.
- Vive no `OnboardingController` (e, no futuro, num `CutsceneController` genérico para o mundo real).

### 3.3 Scanner ("scam mágico")
- **Input:** skill no **Espaço** (`ui_*` action dedicada, ex.: `world_scan`).
- **Detecção:** `Area2D` em forma de cone/retângulo **à frente** do player, orientado pelo *facing*.
  Reposiciona/rotaciona a área conforme a direção do personagem.
- **Lógica:** ao acionar → coleta `Scannable`s sobrepostos → escolhe o alvo (mais próximo / mais
  centralizado) → inicia o scan.
- **Feedback visual:** luz azul (`PointLight2D` + shader/partícula), animação de "varredura".
- **Sinais:** `scan_started(scannable_id)`, `scan_succeeded(scannable_id, reward)`, `scan_failed(scannable_id)`.
- Se o scannable exigir minigame (`requires_minigame`), o scanner **pausa o mundo** e delega ao
  framework de minigame (§3.6); o resultado do minigame decide sucesso/qualidade da recompensa.

### 3.4 Entidade `Scannable` (data-driven)
- Componente/node colocado no mapa. Campos:
  ```
  scan_id            # identificador único
  reward_table_id    # aponta para a tabela de loot (§2.2)
  mode               # once | cooldown(seg) | repeatable
  requires_minigame  # bool
  minigame_id        # se houver
  requires_quest     # gate narrativo ("alguns exigem favores/cuidado")
  difficulty         # alimenta o minigame
  ```
- A própria fala do encapuzado já justifica a variedade (criatura, lugar, objeto; alguns "exigem
  mais cuidado ou pedem favores") → isso são só flags aqui. **A lore já cobre a mecânica.**

### 3.5 Sistema de Missão/Quest
- Máquina de estados: `objetivos[]`, `estado`, `on_complete`.
- **Tutorial (Missão 1):** pode ser **scriptado/bespoke**, acoplado à cutscene — não force o
  sistema genérico ainda.
- **Genérico:** logo depois, generalizar o que o tutorial ensinou (objetivos do tipo
  "fale com X", "escaneie Y", "vá até Z").
- **Dados:** `data/quests/*.json`. **Sinais:** `quest_started(id)`, `objective_completed(id, obj)`,
  `quest_completed(id)`.

### 3.6 Framework de Minigame
- **Base:** `MinigameBase` com `start(config)` e sinal `finished(success: bool, quality: float)`.
- Cada minigame é uma **cena plugável** (`scenes/minigames/<nome>/`).
- O scanner pausa o mundo → instancia o minigame → no fim aplica o resultado (sucesso / qualidade
  da recompensa / falha).
- Começar com **UM** minigame simples; expandir depois (estilo Stardew/Yakuza).

---

## 4. Fluxo da Missão 1 (roteiro técnico do onboarding)

```
1. Fade-in. Câmera no personagem, que anda sozinho (cutscene) e para.
2. NPC encapuzado entra em cena e caminha até o player.
3. Diálogo (data/dialogues/intro_encapuzado.json):
   - lore: o novo jogo de cartas dos magos da capital; escanear itens/lugares/criaturas/heróis
     vira carta; o jogo é febre no continente.
4. Item aparece no centro da tela (o "scam mágico"). Encapuzado o entrega.
5. INPUT LIBERADO. Prompt de tutorial: "Aperte [Espaço] para escanear".
6. Um slime (Scannable: once, reward = carta de slime) está à frente.
7. Player aperta Espaço → scan → popup da carta de slime → carta vai pro inventário (Collection).
8. Diálogo de fechamento:
   - parabéns; nem todo alvo se deixa rastrear assim; alguns exigem cuidado ou favores;
     dá pra rastrear lugares e objetos (podem ou não ter algo);
   - "na taverna parece haver aventureiros interessantes de rastrear" → gancho da Missão 2.
9. Marca tutorial_done. Transição → MUNDO REAL (conecta ao servidor).
```

Assets necessários da Missão 1: salinha instanciada (tileset placeholder ok), sprite do
encapuzado + retrato, sprite do slime, **a carta de slime** (nova), VFX do scanner, item "scam".

---

## 5. Roadmap por Fases (cada fase entrega algo jogável/testável)

| Fase | Entrega | Notas |
|------|---------|-------|
| **0** | Aprender `TileMapLayer` (Godot 4.6) + salinha instanciada com **tileset placeholder grátis** | Não travar a engenharia esperando virar pixel-artist. Arte temporária, troca depois. Personagem em **LPC** na v1 (ver §7.6). |
| **1** | Sistema de Diálogo (cena `.tscn` + loader JSON + sinais GameBus) | Base de tudo. Testável isolado. |
| **2** | Sequenciador + cutscene de abertura do encapuzado (sem scanner) | Já vira intro jogável ponta-a-ponta. |
| **3** | `ScanReward` + Scanner + `Scannable` + carta de slime no inventário | Coração da mecânica nova. |
| **4** | Quest system amarrando 1→2→3 como "Missão 1" + gate `tutorial_done` | Onboarding fechado. |
| **5** | Framework de minigame + 1 minigame ligado a um scannable | Profundidade, com tudo de pé. |
| **6** | Ponte pro mundo real: scanner/quest/itens persistindo no servidor + multiplayer | Reusa tudo acima, agora com `WorldState`. |

**Abertura cinematográfica "bonitinha" (animação caprichada):** tratar como **polish em paralelo**.
Começar com placeholder (fade + texto + arte estática); trocar pela versão final depois. Não deixar
virar gargalo do onboarding.

---

## 6. Pontos de Integração com o Código Existente

- **`Collection`** (`src/autoload/collection.gd`) — recebe cartas de scan (`ScanReward.CARD`).
- **`CosmeticsStore`** (`src/autoload/cosmetics_store.gd`) — recebe sleeves/playmats (`ScanReward.COSMETIC`).
- **`CharacterStore`** — futura origem dos "itens visuais" no personagem do mundo.
- **`GameBus`** (`src/autoload/game_bus.gd`) — novos sinais de diálogo / scan / quest / minigame.
- **Mundo real** (`scenes/world/`, `src/world/`) — só na Fase 6; nada de RPC antes disso.
- **Card model** — a "carta de slime" entra em `data/cards/` (ou um arquivo próprio de cartas
  rastreáveis), respeitando `Card.from_dict()` e o pool jogável.

---

## 7. Decisões em Aberto (para resolver no caminho)

1. **Persistência de "itens visuais":** novo `kind` no inventário do backend vs. `user://` por ora.
2. **Cartas rastreáveis no mesmo JSON do set base** (`taldorian_origins.json`) ou arquivo separado
   (`data/cards/scanned.json`)? Recomendação: arquivo separado, mesmo schema, pra não poluir o set
   competitivo e facilitar balanceamento.
3. **Forma/alcance da área de scan** (cone vs. retângulo; quantos tiles à frente) — afinar no playtest.
4. **Onde mora o sistema genérico de quest** quando sair do tutorial bespoke (provável `src/world/`).
5. **`tutorial_done`** só no backend, só local, ou ambos com reconciliação.

### 7.6 Arte do personagem — LPC na v1 (decisão tomada)
- **v1 usa LPC** (Liberated Pixel Cup): modular de verdade (resolve customização / evita
  personagens iguais) e gratuito. Substituição por arte custom fica para o futuro (provável
  contratar artista), sem dívida técnica **se** o item abaixo for respeitado.
- **Regra de desacoplamento (obrigatória na Fase 0):** o character creator descreve a aparência
  em **slots abstratos** (corpo, cabelo, torso, pernas, calçado…) + um **mapeamento** para o
  spritesheet — nunca com o layout específico do LPC espalhado pelo código.
- **Consequência:** trocar a arte vira um *re-skin* (novas folhas + novo mapeamento), não um
  rewrite. Um artista futuro pode ser briefado para **entregar no mesmo formato de folha do LPC**
  (mesma grade de frames/animações/tamanhos) → entra como *drop-in replacement*.

---

## 8. Princípios que NÃO violar (herdados do projeto)

- Cena não pensa, exibe. Lógica de scan/quest/recompensa fica em `src/` (RefCounted/serviço), não no `.gd` da cena.
- Layout visual montado no `.tscn`, não construído por código no `.gd`.
- Nada de rede no onboarding — é local até a Fase 6.
- Mundo aberto e TCG nunca se misturam em lógica.
- Eventos transientes viajam por sinais do `GameBus`; nunca referenciar uma cena direto de outra.
