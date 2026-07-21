class_name HeroLilith
extends Hero

## Lilith — Sorcerer (Coleção "Ecos do Abismo"). Feiticeira de banimento. Enquanto ativa
## (não exausta), pode gastar uma AÇÃO BÔNUS para marcar um herói inimigo com o Selo da
## Ruína (até o fim do turno): enquanto marcado, cada dano sofrido bane floor(dano/2)
## (mín 1) do topo do deck do dono do herói. A especial (Trevas·Trevas·Água) bane 1 carta
## do deck do oponente por símbolo Trevas na cadeia. Ver Hero.take_damage +
## GameState.on_sealed_hero_damaged / banish_from_deck_top.
const ABILITY_SEAL := "lilith_seal"

func _init() -> void:
	art_key      = "hero_lilith"
	hero_name    = "Lilith"
	hero_class   = HeroClass.SORCERER
	max_hp       = 10
	current_hp   = 10
	base_attack  = 0
	base_defense = 1
	collection   = "Ecos do Abismo"
	symbols_required.assign([GameSymbols.TREVAS, GameSymbols.TREVAS, GameSymbols.AGUA])
	skill_name   = "Maldição do Abismo"
	skill_desc   = "Para cada símbolo {DARK} na chain, o oponente *bane* 1 carta do topo do deck"
	skill_animation = "abyss_curse"   # encenada por Board._on_abyss_curse (evento dedicado)
	passive_name = "Selo da Ruína"
	passive_desc = "*Ação bônus*: marque um herói inimigo com o *Selo da Ruína* até o final do turno; ao sofrer dano, ele *bane* metade das cartas do topo do deck (arredondado para baixo, mín. 1)"

## Selo da Ruína — ação bônus disponível ENQUANTO NÃO EXAUSTA, esteja ela ativa
## (get_active_abilities) ou na retaguarda (get_backline_bonus_ability). Mesmo descritor.
func get_active_abilities(_player: Player, _opponent: Player) -> Array[Dictionary]:
	if state == State.EXHAUSTED:
		return []
	return [_seal_ability()]

## Também ativável pela retaguarda (jogador ativo gasta a ação bônus). Marcada como
## from_backline (atribuída à Lilith) e reveals_self: usar pela retaguarda quebra a
## furtividade da própria Lilith (modal de confirmação, igual ao Darian).
func get_backline_bonus_ability(_player: Player, _opponent: Player) -> Dictionary:
	if state == State.EXHAUSTED:
		return {}
	var ab := _seal_ability()
	ab["from_backline"] = true
	ab["reveals_self"] = true
	return ab

func _seal_ability() -> Dictionary:
	return {
		"id": ABILITY_SEAL,
		"label": "Selo da Ruína",
		"cost": "BONUS",
		"needs_target": true,
		"target_count": 1,
	}

func activate_ability(id: String, player: Player, opponent: Player, targets: Array) -> String:
	match id:
		ABILITY_SEAL:
			if targets.is_empty():
				return ""
			var target: Hero = targets[0]
			# O selo só faz sentido em heróis inimigos (banem do próprio deck ao sofrer dano).
			if not (target in opponent.heroes):
				return ""
			target.sealed_ruin = true
			# Anuncia a névoa negra (VFX) que voa da Lilith até o alvo, nos dois clientes.
			var caster_idx: int = GameState.players.find(player)
			var source_hero_idx: int = player.heroes.find(self)
			var opp_idx: int = GameState.players.find(opponent)
			var target_hero_idx: int = opponent.heroes.find(target)
			GameState.announce_seal_applied(caster_idx, source_hero_idx, opp_idx, target_hero_idx)
			return "Selo da Ruína"
	return ""

## Especial (Trevas·Trevas·Água): conta os símbolos Trevas na cadeia da batalha
## (cartas jogadas + símbolos injetados fora de carta) e bane essa quantidade do topo
## do deck do oponente.
func on_skill_activated(player: Player) -> void:
	var opponent: Player = GameState.players[1 - player.player_index]
	var n := 0
	for c in player.cards_this_battle:
		for s in c.symbols:
			if s == GameSymbols.TREVAS:
				n += 1
	for s in player.bonus_chain_symbols:
		if s == GameSymbols.TREVAS:
			n += 1
	# Bane sem animar cada carta na hora (notify_moves=false): o board encena os banimentos
	# 1 a 1 após a névoa chegar ao deck, a partir do evento abyss_curse com estes art_keys.
	var banished: Array = []
	if n > 0:
		banished = GameState.banish_from_deck_top(opponent.player_index, n, false)
	GameState.announce_abyss_curse(player.player_index, opponent.player_index, banished)
	_skill_activated_this_battle = true
	GameBus.skill_activated.emit(self, skill_desc)
