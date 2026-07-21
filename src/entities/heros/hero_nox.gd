class_name HeroNox
extends Hero

## Nox — Wizard. Herói de tokens: cria Mísseis Mágicos. O DISPARO dos mísseis é
## lógica do próprio token (TokenMagicMissile) — qualquer herói que os controle pode
## dispará-los. A cadeia Raio·Fogo·Raio dobra os mísseis controlados.
const ABILITY_CREATE_MISSILE := "create_missile"
const MISSILE_ID             := "magic_missile"

func _init() -> void:
	art_key          = "hero_nox"
	hero_name        = "Nox"
	hero_class       = HeroClass.WIZARD
	max_hp           = 10
	current_hp       = 10
	base_attack      = 0
	base_defense     = 0
	symbols_required.assign([GameSymbols.RAIO, GameSymbols.FOGO, GameSymbols.RAIO])
	skill_name       = "Tempestade Arcana"
	skill_desc       = "Dobra a quantidade de *Mísseis Mágicos* que você controla"
	passive_name     = "Mísseis Mágicos"
	passive_zone     = "frontline"
	passive_desc     = "*Ação*: descarte 1 carta da mão e crie 2 *Mísseis Mágicos*"

# ── Habilidade ativa por cadeia (Raio · Fogo · Raio) ────────────────────────
## Dobra os Mísseis Mágicos controlados (N → 2N).
func on_skill_activated(player: Player) -> void:
	var current := player.count_tokens(MISSILE_ID)
	for _i in current:
		player.tokens.append(TokenMagicMissile.new())
	_skill_activated_this_battle = true
	GameBus.skill_activated.emit(self, skill_desc)

# ── Habilidades ativadas (consumidas pelo GameState no fluxo de timing) ─────
func get_active_abilities(player: Player, _opponent: Player) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Criar mísseis exige descartar 1 carta — sem cartas na mão, sem criação
	# (fecha a brecha de gerar mísseis infinitos a custo zero).
	if not player.hand.is_empty():
		out.append({
			"id": ABILITY_CREATE_MISSILE,
			"label": "Descartar e Criar 2 Mísseis",
			"cost": "ACTION",
			"needs_target": false,
		})
	return out

func activate_ability(id: String, player: Player, _opponent: Player, _targets: Array) -> String:
	match id:
		ABILITY_CREATE_MISSILE:
			if player.hand.is_empty():
				return ""
			player.tokens.append(TokenMagicMissile.new())
			player.tokens.append(TokenMagicMissile.new())
			# Custo: o jogador escolhe 1 carta da mão para descartar (overlay HAND_DISCARD).
			var indices: Array[int] = []
			for i in player.hand.size():
				indices.append(i)
			GameState.begin_hand_discard(player.player_index, indices, 1, 0,
				"Descarte 1 carta")
			return "Criou 2 Mísseis Mágicos"
	return ""
