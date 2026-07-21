# scenes/ui/boardv2/tutorial/tutorial_director.gd
# Orquestrador da PARTIDA-TUTORIAL (contra o bot fantasma). Só roda quando NetworkState.tutorial_mode.
# O board é a autoridade local (OfflineMultiplayerPeer), então o diretor:
#   - monta a partida de forma DETERMINÍSTICA (decks, mãos, dados);
#   - DIRIGE o bot (índice 1, sem peer) chamando os métodos do GameState direto;
#   - pausa com coaching do Blauber (TutorialCoach) e destaques (TutorialSpotlight);
#   - GATEIA o input do jogador (só a jogada certa em cada passo) via ganchos no board.
# Ver o plano em .claude/plans e CLAUDE.md (modelo de rede / fases).
extends Node

const COACH_SCENE     := preload("res://scenes/ui/boardv2/tutorial/tutorial_coach.tscn")
const SPOTLIGHT_SCENE := preload("res://scenes/ui/boardv2/tutorial/tutorial_spotlight.tscn")

# Decks fixos (heróis). As cartas viram determinísticas pela reescrita de mão (ver _cards).
const PLAYER_DECK := { "heroes": ["Poppy", "Nox", "Irena"] }
const BOT_DECK    := { "heroes": ["Slime", "Irena", "Hakai"] }

# Ids de carta (data/cards/taldorian_origins.json) — ver plano.
const C_TERRA_ACTION := 86   # Rolando (ação/terra 4·0, s/efeito)
const C_FOGO_BONUS   := 61   # Eco Ardente (bônus/fogo 2·0, efeito attack_if_nth_card AFTER_REACTION)
const C_FOGO_REACT   := 42   # Reflexivo Ofensivo (reação/fogo 1·0)
const C_TERRA_SPARE  := 2    # Perfeito Equilíbrio (ação/terra — sobra p/ o arsenal)
const C_AGUA_A       := 18   # Fluxo Sereno (mulligan)
const C_AGUA_B       := 19   # Corrente Restauradora (mulligan)
const C_BOT_REACT    := 39   # Bloqueio Instintivo (reação +1 def, s/efeito)
const C_BOT_ACTION   := 1    # Golpe Bruto (ação/fogo, s/efeito)

# ── Textos do Blauber ─────────────────────────────────────────────────────────
const TXT_DICE := "Para iniciar o jogo, ambos os jogadores jogam os dados. Quem tirar o maior valor decide quem começa jogando.\n\nArraste seus dados para arremessar!"
const TXT_DICE_WIN := "Isso! A primeira vitória já é minha. Quem ganha nos dados decide quem começa jogando... e, como você é iniciante, vou deixar essa com você."
const TXT_MULLIGAN := "Essa é a fase de preparação. No início de todo duelo cada jogador começa com 6 cartas e escolhe duas para mandar ao fundo do deck — assim evitamos a desculpinha de \"ah, peguei uma mão ruim\".\n\nClique nas suas duas cartas de Água para devolvê-las."
const TXT_HERO_INTRO := "Agora que terminamos os preparos, vamos ao jogo de verdade! Todo combate começa com a seleção do herói: escolha um para a linha de frente — ele vai enfrentar o meu."
const TXT_HERO_STATS := "Cada herói tem seus status: [b]Ataque[/b], [b]Defesa[/b] e [b]HP[/b] (vida).\n\nCada herói tem uma habilidade e uma habilidade especial! As habilidades podem ser diversas — algumas ativam passivamente, outras não. Já as habilidades especiais precisam dos elementos na chain jogados exatamente na ordem exibida — não se preocupa, eu já vou te mostrar."
const TXT_POPPY_STATS := "No caso da Poppy, além dos status: a habilidade dela ativa passivamente — enquanto ela não aumentar a própria defesa, o ataque dela recebe +1.\n\nJá a habilidade especial dá +3 de ataque, ativada quando você joga a sequência de elementos que vou te mostrar.\n\nEla é bem simples, né? Mas não se engane: nas mãos certas, pode ser muito poderosa."
const TXT_STEALTH := "Reparou que as cartas dos heróis estão viradas para baixo? Os heróis entram na linha de frente \"furtivos\". Assim, quem escolhe primeiro não fica em desvantagem — e você nunca sabe qual carta o oponente tem na manga."
const TXT_TURN_INTRO := "Um combate tem vários turnos, onde os dois heróis da linha de frente se enfrentam até um deles cair, até os dois ficarem sem cartas, ou até ambos passarem.\n\nEm cada turno você pode jogar uma Ação e uma Ação Bônus. Vamos lá: jogue sua carta de Ação (a de Terra)."
const TXT_STEALTH_REVEAL := "Sempre que você joga uma carta, seu herói sai da furtividade e se revela ao oponente."
const TXT_CARD_MODIFIERS := "Toda carta traz modificadores: um valor de [b]Ataque[/b], um de [b]Defesa[/b] e um [b]Elemento[/b]. Esses valores se somam aos do seu herói no combate."
const TXT_REACTION_INTRO := "Sempre que um jogador joga uma Ação ou Ação Bônus, o oponente pode responder com uma carta de [b]Reação[/b]. Viu? Eu já reagi à sua jogada.\n\nAgora jogue sua Ação Bônus (a de Fogo)."
const TXT_EFFECTS := "Muitas cartas, além dos modificadores, têm [b]efeitos[/b] — estratégias essenciais que ditam o ritmo e o resultado do jogo. Escolha sempre com sabedoria!\n\nOs efeitos de Ação e Ação Bônus se resolvem [b]depois[/b] da reação do oponente."
const TXT_OPPORTUNITY := "Essa parece uma oportunidade de ouro! Jogue uma Reação de Fogo para formar a sequência Terra → Fogo → Fogo e ativar a habilidade especial da Poppy!"
const TXT_ARSENAL := "Droga... não acredito que você derrotou meu grande Slime. Sorte de principiante!\n\nEssa é a fase de Arsenal: se o combate acabou e você ainda tem cartas, pode guardar uma no seu arsenal. No fim de cada combate você compra 4 cartas novas — então o arsenal é uma arma poderosa: te deixa começar o próximo combate com 5 cartas disponíveis.\n\nGuarde sua última carta no arsenal."
const TXT_EXHAUSTION := "Repare que a Poppy está exausta. Isso é normal: todo herói volta exausto da linha de frente e não pode ativar habilidades nem voltar a lutar até que todos os heróis tenham combatido — ou que ele seja o único disponível."
const TXT_FAREWELL := "Bom, esse é o básico de Taldorian! Espero ter sido um bom professor.\n\nVou desistir dessa batalha... já dá pra ver que você não me derrotaria de qualquer maneira. Até mais!"

# Hints de AÇÃO (texto piscando no topo, sem escurecer — mostrados enquanto o jogador age).
const HINT_DICE := "➤ Arraste seus dados para arremessar!"
const HINT_MULLIGAN := "➤ Clique nas suas 2 cartas de Água (as destacadas) e confirme."
const HINT_HERO := "➤ Clique na Poppy para enviá-la à linha de frente."
const HINT_PLAY_TERRA := "➤ Sua vez! Jogue a Ação de Terra (a carta destacada)."
const HINT_PLAY_BONUS := "➤ Agora jogue a Ação Bônus de Fogo (a carta destacada)."
const HINT_PLAY_REACTION := "➤ Jogue a Reação de Fogo (a carta destacada) para ativar a Poppy!"
const HINT_ARSENAL := "➤ Clique na sua carta (a do centro) para guardá-la no arsenal."

var _board: Node = null
var _coach: CanvasLayer = null
var _spotlight: CanvasLayer = null
var _allowed_card_names: Array[String] = []   # gate da mão: só estas cartas jogáveis (vazio = nenhuma)
var _dice_handled: bool = false

# ── setup ─────────────────────────────────────────────────────────────────────
func setup(p_board: Node) -> void:
	_board = p_board

func begin() -> void:
	_coach = COACH_SCENE.instantiate()
	add_child(_coach)
	_spotlight = SPOTLIGHT_SCENE.instantiate()
	add_child(_spotlight)
	# Monta a partida determinística (os dois decks). Fica em OPENING_ROLL (jogador arremessa).
	GameState.start_match(PLAYER_DECK, BOT_DECK)
	GameState._emit_sync()
	_run_script()

# ── ganchos chamados pelo board ────────────────────────────────────────────────
## Chamado após board._refresh_hand_interactivity: só deixa jogável a carta do passo atual.
func gate_hand(card_views: Array) -> void:
	for child in card_views:
		var view := child as CardView
		if view == null or view.card == null:
			continue
		view.set_interactable(view.card.card_name in _allowed_card_names, true)

## Chamado após board._refresh_pass_button: no tutorial o jogador nunca passa (o diretor controla).
func gate_pass(center_bar: Node) -> void:
	if center_bar == null:
		return
	center_bar.set_pass_state(false)
	if center_bar.has_method("stop_timer"):
		center_bar.stop_timer()

## Chamado pelo board quando o jogador arremessa os dados: força o resultado roteirado.
func on_player_dice_throw(dir_x: float, dir_y: float, _force: float) -> void:
	if _dice_handled:
		return
	_dice_handled = true
	_scripted_dice(dir_x, dir_y)

# ── roteiro ────────────────────────────────────────────────────────────────────
func _run_script() -> void:
	await _await_until(func() -> bool: return GameState.players.size() >= 2)

	# BEAT 1 — Rolagem de dados: explica (some), e o hint pisca no topo enquanto o jogador arrasta.
	await _coach.show_message(TXT_DICE)
	_coach.show_hint(HINT_DICE)
	await _await_until(func() -> bool: return _phase() == "OPENING_MULLIGAN")
	if _ended(): return

	# BEAT 2 — Preparação (mulligan).
	_rewrite_hands([C_TERRA_ACTION, C_FOGO_BONUS, C_FOGO_REACT, C_TERRA_SPARE, C_AGUA_A, C_AGUA_B],
		[C_BOT_REACT, C_BOT_ACTION, C_AGUA_A, C_AGUA_B])
	await _coach.show_message(TXT_MULLIGAN)
	_coach.show_hint(HINT_MULLIGAN)          # hint sem dim + cartas-alvo destacadas
	_mulligan().restrict_to([4, 5])           # só as 2 cartas de Água
	await _await_until(func() -> bool: return GameState.has_completed_opening_mulligan(0))
	_coach.hide_hint()
	_mulligan().restrict_to([])
	GameState.submit_opening_mulligan(1, 2, 3)   # bot devolve os 2 filler de Água
	await _await_until(func() -> bool: return _phase() == "HERO_SELECTION")
	if _ended(): return

	# BEAT 3 — Seleção de herói.
	_rewrite_hands([C_TERRA_ACTION, C_FOGO_BONUS, C_FOGO_REACT, C_TERRA_SPARE], [C_BOT_REACT, C_BOT_ACTION])
	_hero_pick().disable_timer_for_tutorial()
	await _coach.show_message(TXT_HERO_INTRO)
	_spotlight.show_hero(_hero_by_name(0, "Poppy"))
	await _coach.show_message(TXT_HERO_STATS)    # parte 1: status + habilidade/especial (geral)
	await _coach.show_message(TXT_POPPY_STATS)   # parte 2: específico da Poppy
	_spotlight.hide_spot()
	_coach.show_hint(HINT_HERO)
	_hero_pick().restrict_to_hero("Poppy")
	await _await_until(func() -> bool: return GameState.has_submitted_hero_pick(0))
	_coach.hide_hint()
	GameState.submit_hero_pick(1, 0)   # bot escolhe o Slime (slot 0)
	await _await_until(func() -> bool: return _phase() == "ACTION")
	if _ended(): return
	await _coach.show_message(TXT_STEALTH)

	# BEAT 4 — Turno: Ação (Terra) → reação do bot → Ação Bônus (Fogo).
	await _coach.show_message(TXT_TURN_INTRO)
	_coach.show_hint(HINT_PLAY_TERRA)
	_allow(["Rolando"])
	await _await_until(func() -> bool: return GameState.get_segment_action_done(0))
	_allow([])
	_coach.hide_hint()
	await _coach.show_message(TXT_STEALTH_REVEAL)
	# Bot reage (+1 def) à ação do jogador.
	await _await_until(func() -> bool: return GameState.get_reaction_window_for() == 1)
	GameState.action_play_card(1, _bot_index("Bloqueio Instintivo"))
	# Spotlight: cartas têm modificadores.
	_spotlight.show_card(_make_card(C_TERRA_ACTION))
	await _coach.show_message(TXT_CARD_MODIFIERS)
	_spotlight.hide_spot()
	await _coach.show_message(TXT_REACTION_INTRO)
	# Volta ao segmento do jogador (janela fechada) → Ação Bônus.
	await _await_until(func() -> bool: return GameState.get_next_action_player_index() == 0 and GameState.get_reaction_window_for() == -1)
	_coach.show_hint(HINT_PLAY_BONUS)
	_allow(["Eco Ardente"])
	await _await_until(func() -> bool: return GameState.get_segment_bonus_done(0))
	_allow([])
	_coach.hide_hint()
	# Spotlight HD da carta jogada + explicação de efeitos.
	_spotlight.show_card(_make_card(C_FOGO_BONUS))
	await _coach.show_message(TXT_EFFECTS)
	_spotlight.hide_spot()
	# Bot passa a janela de reação aberta pelo bônus.
	await _await_until(func() -> bool: return GameState.get_reaction_window_for() == 1)
	GameState.action_pass(1)

	# BEAT 5 — Segmento do bot → reação do jogador (ativa a especial da Poppy) → combate.
	await _await_until(func() -> bool: return GameState.get_next_action_player_index() == 1 and _phase() == "ACTION" and GameState.get_reaction_window_for() == -1)
	if _ended(): return
	GameState.action_play_card(1, _bot_index("Golpe Bruto"))
	await _await_until(func() -> bool: return GameState.get_reaction_window_for() == 0)
	await _coach.show_message(TXT_OPPORTUNITY)
	_coach.show_hint(HINT_PLAY_REACTION)
	_allow(["Reflexivo Ofensivo"])
	await _await_until(func() -> bool: return GameState.get_reaction_window_for() != 0)
	_allow([])
	_coach.hide_hint()
	# Bot passa o segmento → combate resolve → Slime morre → engine entra em END (arsenal).
	await _await_until(func() -> bool: return GameState.get_next_action_player_index() == 1 and GameState.get_reaction_window_for() == -1 and _phase() == "ACTION")
	if _ended(): return
	GameState.action_pass(1)

	# BEAT 6 — Arsenal (guardar a carta que sobrou).
	await _await_until(func() -> bool: return _phase() == "END")
	if _ended(): return
	# ESPERA o VFX de combate terminar — enquanto ele toca, cobre/bloqueia a carta do arsenal
	# (era o bug de "não dá pra clicar" ao pular o diálogo cedo demais).
	await _await_until(func() -> bool: return not _combat_vfx_playing())
	await _wait(0.4)
	await _coach.show_message(TXT_ARSENAL)
	_coach.show_hint(HINT_ARSENAL)
	_arsenal().restrict_to([0])   # a única carta na mão (Perfeito Equilíbrio)
	# Espera o jogador clicar; se não guardar em ~7s (algum bloqueio de UI), guarda sozinho (nunca trava).
	var _t := 0.0
	while not GameState.get_end_submitted(0) and _t < 8.0:
		_arsenal().tutorial_keep_clickable()   # mantém a carta clicável todo frame
		await get_tree().process_frame
		_t += get_process_delta_time()
	if not GameState.get_end_submitted(0):
		GameState.finish_end_battle(0, 0)
	_coach.hide_hint()

	# BEAT 7 — Exaustão + desistência do bot → vitória.
	await _await_until(func() -> bool: return _phase() == "HERO_SELECTION" or _ended())
	if _ended(): return
	_hero_pick().disable_timer_for_tutorial()
	await _coach.show_message(TXT_EXHAUSTION)
	await _coach.show_message(TXT_FAREWELL)
	GameState._conclude_match(0)   # bot desiste → jogador vence (volta pra taverna via board)

# ── helpers de estado ──────────────────────────────────────────────────────────
func _scripted_dice(dir_x: float, dir_y: float) -> void:
	_coach.hide_hint()
	GameState._dice_values    = [[2, 3], [5, 5]]
	GameState._dice_thrown    = [true, true]
	GameState._dice_throw_vec = [Vector2(dir_x, dir_y), Vector2(0.4, -1.0)]
	GameState._dice_winner    = 1   # Blauber vence a rolagem
	GameState._emit_sync()          # board anima os dois lados
	await _wait(2.2)
	await _coach.show_message(TXT_DICE_WIN)
	GameState._first_player = 0      # jogador começa
	GameState.battle.current_phase = BattleManager.Phase.OPENING_MULLIGAN
	GameState.battle.emit_phase_changed()
	GameState._emit_sync()

func _rewrite_hands(player_ids: Array, bot_ids: Array) -> void:
	GameState.players[0].hand = _cards(player_ids)
	GameState.players[1].hand = _cards(bot_ids)
	GameState._emit_sync()

func _cards(ids: Array) -> Array[Card]:
	var out: Array[Card] = []
	for id in ids:
		var d := Collection.get_card_dict_by_id(int(id))
		if not d.is_empty():
			out.append(Card.from_dict(d))
	return out

func _make_card(id: int) -> Card:
	return Card.from_dict(Collection.get_card_dict_by_id(id))

func _allow(names: Array) -> void:
	_allowed_card_names.assign(names)
	if _board.has_method("_refresh_hand_interactivity"):
		_board._refresh_hand_interactivity()

func _bot_index(card_name: String) -> int:
	var hand: Array = GameState.players[1].hand
	for i in hand.size():
		if hand[i].card_name == card_name:
			return i
	return -1

func _hero_by_name(player_idx: int, hero_name: String) -> Hero:
	for h in GameState.players[player_idx].heroes:
		if h.hero_name == hero_name:
			return h
	return GameState.players[player_idx].heroes[0]

func _phase() -> String:
	return GameState.battle.phase_to_string(GameState.battle.current_phase)

func _ended() -> bool:
	return GameState.is_game_over()

func _combat_vfx_playing() -> bool:
	return _board.has_method("_combat_vfx_playing") and _board._combat_vfx_playing()

func _await_until(cond: Callable) -> void:
	while not bool(cond.call()):
		await get_tree().process_frame

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

# ── acesso às telas do board ────────────────────────────────────────────────────
func _mulligan() -> Node:
	return _board.get_node("PhaseOverlay/MulliganScreen")

func _hero_pick() -> Node:
	return _board.get_node("PhaseOverlay/HeroPickScreen")

func _arsenal() -> Node:
	return _board.get_node("PhaseOverlay/ArsenalScreen")
