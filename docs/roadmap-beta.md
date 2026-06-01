# Taldorian — Roadmap para o Closed Beta

Documento vivo. Planejamento dos próximos passos rumo a uma versão estável de
closed beta capaz de suportar ~30 jogadores em um servidor (mundo aberto +
partidas entre eles).

Organizado em 3 frentes: **(1) Game de cartas**, **(2) Mundo aberto**,
**(3) Geral / estabilidade**.

> **Baseline / validação:** este roadmap foi conferido contra o código em
> jun/2026. O `CLAUDE.md` está parcialmente desatualizado (ex.: lista Deck Builder
> como pendente — ele está pronto). O `DOCUMENTACAO.md` (Maio/2026) é o status mais
> fiel do lado TCG e confirma como pendentes: SFX, VFX por herói, HUD de fase/turno,
> log de ações, perfil, histórico de partidas, IA/solo e online/matchmaking — tudo
> coberto aqui. O lado do mundo tem várias **cascas de UI prontas com dados mock**
> (ver "Estado atual validado" na seção 2); o trabalho é o sistema/servidor atrás
> delas. Hoje o jogo é **LAN-only** — o Modelo A é a ponte para o servidor único.

---

## 🔒 Decisão de Arquitetura de Rede — MODELO A (travado)

> **Status:** decidido. Todo o roadmap assume este modelo.

### O problema
Hoje convivem dois modelos de rede:
- **TCG:** host é a autoridade (`peer_id == 1`); cliente manda intenção via
  `rpc_id(1, ...)`. Bom para 1×1 isolado.
- **Mundo:** servidor dedicado (`src/world/world_server.gd`) é autoridade de N
  jogadores; todos são clientes (`peer_id != 1`).

Quando dois jogadores que **já são clientes do mundo** querem se enfrentar,
ninguém é `peer_id == 1` para hospedar o `GameState`. Por isso o
`EncounterManager` (`src/world/encounter_manager.gd`) está vazio.

### A decisão: Modelo A — "partida é uma sala dentro do único servidor"
- Existe **um único servidor de jogo** (o `world_server.gd` que já temos). Ele
  roda o mundo **e** todas as partidas.
- Uma **partida NÃO é uma conexão nova nem um servidor novo** — é apenas um
  objeto `GameState` na memória do servidor, associado a 2 jogadores ("sala").
- Cada jogador mantém **uma única conexão ENet** com o servidor o tempo todo (a
  mesma que usa para andar no mundo). Ao iniciar uma partida, nenhuma conexão
  nova é aberta.
- O servidor é a **autoridade** da partida → anti-cheat de graça, sem NAT entre
  jogadores, confiável para ranqueada.

### Fluxo concreto (peer 1 = servidor; 42 = Ana; 57 = Bia)
```
1. Ana clica "duelar"  → rpc_id(1, "pedir_partida", 57)   [mesma conexão do mundo]
2. Servidor cria sala  → salas[7] = GameState.new(); salas[7].jogadores = [42, 57]
                         (apenas um new() — sem conexão/processo novo)
3. Servidor avisa os 2 → rpc_id(42, "entrar_partida", 7); rpc_id(57, ...)
                         clientes trocam para board.tscn, seguem conectados
4. Ana joga carta      → rpc_id(1, "rpc_play_card", idx)
                         servidor: "peer 42 ∈ sala 7" → aplica em salas[7]
                         devolve estado SÓ aos 2: rpc_id(42,...); rpc_id(57,...)
5. Fim                 → servidor faz POST /matches (resultado/ranking) na API REST
                         os 2 voltam a andar no mundo; conexão nunca caiu
```

### Modelos descartados
- **B (peer-host):** um jogador vira servidor ENet e o outro conecta direto.
  Descartado: NAT (falha fora de LAN), cheating (jogador é a autoridade), e
  Godot só tem um `multiplayer_peer` ativo por padrão.
- **C (híbrido):** mundo dedicado + socket P2P paralelo na partida. Pior dos dois
  (duas conexões, NAT, complexidade). Descartado.

### Consequência técnica (o único custo real de A)
Refatoração — **não** é servidor novo, é reorganização do código existente:
1. **`GameState` deixa de ser singleton.** Hoje é autoload único = "a partida".
   Passa a ser instanciável; o servidor mantém `salas: Dictionary[int, GameState]`.
2. **Roteamento de RPC por sala.** Ao receber `rpc_*`, o servidor descobre a sala
   do `get_remote_sender_id()` e despacha para o `GameState` correto.
3. **Sync direcionado.** `_sync_state` vai só aos 2 peers da sala via `rpc_id`,
   nunca broadcast para todos os 30.
A lógica de jogo (combate, símbolos, efeitos, fases) permanece intacta. Custo de
CPU/banda é irrisório (jogo por turnos = matemática discreta).

### As duas (e únicas) peças de backend
| Peça | O que é | Tempo real? | Quantos |
|---|---|---|---|
| **Servidor de jogo** (Godot headless) | Roda mundo + partidas | Sim (ENet) | 1 no beta |
| **API REST** (Kotlin/Spring) | Contas, decks, coleção, ranking | Não (HTTP) | 1 |
A API **não** participa da partida; só persiste conta/deck e recebe o resultado.

---

## 1) Game de cartas

### 1.1 Efeitos sonoros
- Criar autoload `AudioManager` (`src/autoload/audio_manager.gd`): pool de
  `AudioStreamPlayer`, buses Master/Music/SFX/UI, `play_sfx(key)`, volume
  persistido. (Hoje só há música em `lobby.gd:277`.)
- Disparar SFX a partir de sinais já existentes do `GameBus`: `card_played`,
  `hero_damaged`, `hero_healed`, `hero_defeated`, `combat_resolved`,
  `skill_activated`, `symbol_added`, `reaction_window_opened`, `phase_changed`,
  `game_over`.
- Controles de volume na tela de pause (`scenes/ui/pausemenu/`).

### 1.2 Animações de todos os heróis
- **O pipeline central já existe e funciona:** `GameBus.skill_activated` →
  `board.gd:_on_skill_activated()` → `_play_vfx(anim_key)`, com a chave vinda de
  `hero.skill_animation` / `hero.passive_animation`. Já há também texto flutuante
  "⚡ skill!" e popup do herói (`board.gd:420-448`).
- **VFX já implementados** (3 heróis, em `scenes/vfx/`): Poppy (`battle_fury`),
  Irena (`holy_heal` + `single_target_heal`) e Ieldor (`arrow_rain`).
- **Faltam apenas 3 heróis:** Hakai (Instinto de Caça / furtivo), Nissin (Passos
  Ágeis) e Valkar (Escudo de Espinhos). Para cada um: criar a cena de VFX em
  `scenes/vfx/`, definir `skill_animation` no herói e adicionar o ramo
  correspondente no `match` de `_play_vfx`.
- VFX reutilizáveis de estado (opcional): revelar herói face-down, exaustão,
  derrota.

### 1.3 Mensagens claras de "o que fazer agora"
Cobre dois tipos de mensagem: **(a)** estado geral do turno e **(b)** instruções
pontuais durante efeitos de carta.

**(a) Estado geral do turno**
- Banner de instrução contextual no board: "Sua vez — jogue ACTION ou passe",
  "Aguardando reação do oponente…", "Janela de reação", "Escolha seu herói".
- Dirigido por `phase_changed` + `turn_started` + `reaction_window_opened`; a
  **lógica de qual mensagem** mora em `src/core/`, a cena só exibe.
- Destacar cartas jogáveis no momento (filtrar por timing válido) e desabilitar
  as demais.

**(b) Instruções durante efeitos de carta**
- **Efeitos interativos (que pausam por input) — já cobertos.** Existe
  `GameState.begin_*_pick(..., instruction)` e os efeitos já passam textos claros
  (ex.: `effect_tutor_action` → "Escolha uma carta do seu baralho para colocar na
  mão"; `effect_discard_for_attack` → "Descarte uma carta para ganhar +N de
  ataque"). O overlay `pick_card` mostra via `get_pending_pick_instruction()`.
  - **A fazer:** padronizar o mesmo nível de clareza nos outros overlays —
    `pick_symbol` hoje só diz "Escolha N elementos" (genérico, sem dizer de qual
    carta/por quê) e `backline_ability` só tem "Sim/Não". Dar a eles o mesmo
    campo de instrução contextual.
- **Efeitos que resolvem sozinhos (sem input) — gap principal.** Quando um efeito
  dispara automaticamente (ex.: "+1 ATK por símbolo FOGO", "se dano == 0 recebe 1
  e compra 1", ricochete, contra-ataque, condicional de "1ª carta do turno"), o
  jogador não é avisado do que aconteceu nem **por quê** a condição foi/não foi
  satisfeita.
  - **A fazer:** feedback inline (texto flutuante curto perto da carta/herói:
    "Ricochete! +2", "Condição não atingida") **e** entrada detalhada no histórico
    (1.4). A descrição de "o que o efeito fez e por quê" deve ser gerada no
    `src/core/` (efeito/`GameState`), nunca na cena.

### 1.4 Histórico de jogadas (battle log)
- Novo sinal `GameBus.log_entry(entry: Dictionary)` emitido pelo `GameState` a
  cada ação relevante (carta + origem, efeito, símbolo, dano, skill, revelação,
  derrota).
- Log **gerado no servidor** e sincronizado (entra no `_sync_state`) → ambos veem
  o mesmo histórico (essencial para disputas/ranqueada).
- UI: overlay `scenes/ui/boardv2/battle_log/`, lista rolável, abre/fecha por
  botão/atalho, agrupada por rodada.
- **Dependência cruzada com 1.3(b):** a "explicação do que o efeito fez e por quê"
  é gerada **uma vez** no `src/core/` (efeito/`GameState`) e alimenta tanto o
  feedback inline de 1.3(b) quanto a entrada do histórico aqui. Projetar o
  `log_entry` para carregar essa descrição estruturada, evitando duplicar a
  lógica nas duas features.

### 1.5 Chat na partida
- Reaproveitar o padrão de chat do `WorldState`. Servidor retransmite apenas aos
  participantes da sala. Novo sinal `GameBus.match_chat_received`.
- Considerar emotes rápidos para reduzir toxicidade.

### 1.6 Sistema ranqueado
- Depende do backend (V2). Servidor reporta resultado autoritativo (`POST /matches`).
- Elo/MMR no backend; matchmaking por faixa; fila acessível pela Arena (2.3).
- Tela de perfil/ranking lê de `GET /leaderboard`.

---

## 2) Mundo aberto

> **Estado atual validado (jun/2026):** boa parte da **UI** do mundo já existe —
> mas em grande parte como *casca com dados mock*. O trabalho real é construir os
> **sistemas e o servidor por trás** dessas telas, não as telas.
> - `scenes/ui/worldhud/world_hud.gd` (shell completo: PlayerCard com gold/rank/XP,
>   Chat com 3 abas global/privado/guild, IconBar battle/inventory/decks/friends/
>   logout, popover de amigos). **Porém:** só o chat **global** é real (liga em
>   `WorldState.request_chat`); privado, guild, lista de amigos, gold, rank e XP
>   são **display mock** (chat ambiente fake, `set_player`/`set_friends` recebem
>   dados de fora que ninguém alimenta).
> - Deck Builder **pronto e integrado ao lobby** (`scenes/ui/deck_builder/`).
> - Booster Shop **funcional localmente** (ver 2.2).
> - `CharacterStore` persiste o personagem do mundo em `user://character.json`.

### 2.1 Mapas principais
- `taldorian_city.tscn` **existe mas é um stub vazio** (3 linhas, 1 nó) — embora
  seja o mapa de spawn (`world_state.gd:27`). Construir de fato o mapa (hub
  social) com os tilesets já presentes (`scenes/world/assets/winlu/`; há também
  `assets/sprites/tilessets/guild.png`).
- Pontos de interesse (NPC/portal) que abrem telas: Loja de Cosméticos, Loja de
  Boosters, Arena, Guilda.
- Colisão real de tiles (hoje `_process_move` só checa limites 1..200 —
  `world_state.gd:62`).

### 2.2 Lojas (cosméticos e boosters)
- **Boosters — UI + economia local já funcionam.** `scenes/ui/booster_shop/`
  tem ouro persistido (`user://booster_gold.json`, `STARTING_GOLD`, `PACK_PRICE`),
  compra de pacote e `Collection.add_cards(...)`. **Gap:** é **client-side e
  isolado** (qualquer um edita o JSON; o ouro do World HUD é outro valor mock).
  Para o beta com Modelo A: mover o sorteio e o débito para o **servidor**
  (anti-cheat) e unificar numa **única moeda** (ver abaixo).
- **Cosméticos:** já há `CosmeticsStore` + `cosmetics.json` e um `cosmetics_panel`
  no Deck Builder. Ligar a um NPC; compra debita a moeda unificada e concede.
- Requer **moeda de jogo única e autoritativa** (entidade no backend: saldo +
  transações), substituindo o ouro local do booster shop.

### 2.3 Arena
- Entrada para matchmaking (casual e ranqueada). Ao parear, o servidor (Modelo A)
  cria a sala de partida e move ambos ao `board.tscn`. Implementação real do
  `EncounterManager` (hoje stub) acontece aqui.

### 2.4 Sistema de amizade
- **UI já existe** (popover + lista de amigos + badge de online no `world_hud.gd`
  via `set_friends`), mas hoje é mock — ninguém alimenta a lista.
- **A fazer (backend + wiring):** `friendships` (pending/accepted/blocked) +
  endpoints add/accept/remove/list; presença online real (reusar `_players` do
  `WorldState`) ligada ao `set_friends`; convite para duelo/guilda.

### 2.5 Sistema de guilda
- **UI já existe parcialmente:** aba de chat "guild" no `world_hud.gd` e tileset
  `assets/sprites/tilessets/guild.png`. A aba guild hoje é mock (só global é real).
- **A fazer (backend + wiring):** `guilds`, `guild_members` (líder/oficial/membro),
  convites; tornar a aba de chat "guild" um canal real; NPC/portal de Guilda →
  criar/entrar; futuramente salão instanciado.

### 2.6 Missões iniciais (onboarding → primeiras cartas)
- Backend: `quests` + `player_quest_progress`; recompensa = cartas/heróis/moeda.
- Cadeia tutorial: "fale com o NPC" → "monte seu primeiro deck" → "vença um PvE"
  → concede o deck inicial. PvE precisa de `start_encounter_vs_npc` (stub) com IA
  simples.
- É o caminho que dá as **primeiras cartas** ao jogador novo.

---

## 3) Geral — estabilidade para o closed beta (30 jogadores)

### 3.1 Backend (fundação — plano em `docs/taldorian-api-plan.md`)
> **Estratégia de persistência em fases.** A API **continua sendo requisito do
> beta**, mas é sequenciada **mais tarde e de forma incremental** — durante o
> desenvolvimento, persistência em **JSON local** (cliente) + **JSON no servidor**
> (dados compartilhados) reduz o atrito de iteração/teste. A troca JSON→API sai
> barata porque **tudo passa por um *store*** (a UI nunca lê/grava arquivo direto).
>
> - **Fase 1 (agora):** dados do jogador em `user://` via stores já existentes
>   (`DeckStore`, `Collection`, `CosmeticsStore`, `CharacterStore`). Dados
>   **compartilhados** (moeda unificada, amizade, guild, ranked) em **JSON no
>   servidor de jogo** — nunca só no cliente. Cada install recebe um **UUID local**
>   (guardar no `CharacterStore`) como id de conta provisório, deixando o formato
>   já pronto para a API.
> - **Fase 2 (antes do beta, incremental):** subir a API (V1: Auth/JWT, catálogo,
>   coleção, CRUD de decks; Postgres + Flyway via `docker-compose`) e trocar a
>   *implementação* de cada store, um por vez — sem mexer na UI nem na lógica.
>   Criar autoload `api_client.gd` (previsto no doc, ainda não existe) com refresh
>   automático de token. V2: `POST /matches`, leaderboard, perfil público →
>   habilita ranqueada. Tabelas novas além do doc: moeda/transações, amizades,
>   guildas, missões.
> - **Fase 3:** integração final + migração do JSON do servidor para o Postgres.
>
> **Regra mental:** API ≠ servidor de tempo real. Adiar a API **não** adia o
> Modelo A (3.2), que funciona com deck vindo do JSON local do cliente.

### 3.2 Servidor autoritativo escalável (Modelo A — item crítico)
- **Refatorar `GameState` de singleton para multi-instância** + roteamento de RPC
  por sala + sync direcionado (ver "Consequência técnica" acima).
- Mundo + partidas no mesmo processo headless.
- Teste de carga: 30 conexões andando + ~15 partidas simultâneas. Medir o
  `_sync_world.rpc` — hoje envia **estado completo a cada movimento**
  (`world_state.gd:65`), o que **não escala**: trocar por deltas / área de
  interesse.

### 3.3 Identidade e sessão
- Login real (API) substitui `NetworkState.player_name = "Jogador"` hardcoded.
- Vincular peer_id ENet ↔ conta autenticada (handshake com token em
  `_rpc_enter_world`).
- Validar tudo no servidor: deck legal, jogada legal, itens possuídos.

### 3.4 Robustez de rede
- Reconexão/timeout. Hoje desconexão só apaga de `_players`. Tratar queda em
  partida (auto-derrota/pausa) e no mundo (reconexão suave).
- Versionamento de protocolo (rejeitar cliente desatualizado).

### 3.5 Qualidade e operação
- Testes automatizados do core (expandir `src/ui/test_mechanics.gd` para combate,
  efeitos, cadeia de símbolos).
- Logging/telemetria server-side; tela de erro amigável no cliente; painel admin
  mínimo (conceder itens, banir, ver partidas ativas).
- Build/deploy: empacotar cliente, hospedar servidor (VPS), CI.

---

## Ordem sugerida (caminho crítico)

1. **Backend V1 + `api_client.gd` + login real** — destrava identidade, coleção,
   decks.
2. **Refatorar `GameState` para multi-instância + Modelo A** — destrava partidas
   no mundo. Maior risco: atacar cedo.
3. **`taldorian_city.tscn` + colisões + HUD do mundo** (assets em
   `docs/world-hud/`).
4. **`EncounterManager` real: PvE (missões) e PvP (Arena/matchmaking).**
5. **Battle log + mensagens contextuais + SFX** — alto impacto na clareza, custo
   baixo.
6. **Animações dos 5 heróis restantes.**
7. **Backend V2 + ranqueada + chat de partida.**
8. **Lojas, amizade, guilda, moeda.**
9. **Endurecimento: deltas de sync, reconexão, teste de carga 30 jogadores,
   telemetria.**
