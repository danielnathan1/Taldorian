# src/entities/tokens/token_magic_missile.gd
## Míssil Mágico — token de dano direto. Criado pela ação do Nox (Wizard) ou por
## cartas (ex.: Salva de Mísseis). No turno do dono, todos os mísseis podem ser
## disparados: cada um causa `damage` de dano direto a um herói à escolha (aliado
## ou inimigo). O DISPARO é lógica do token — qualquer herói que controle mísseis
## pode dispará-los. São destruídos no fim da batalha.
class_name TokenMagicMissile
extends Token

const ABILITY_FIRE := "fire_missiles"

var damage: int = 1

func _init() -> void:
	token_id    = "magic_missile"
	token_name  = "Míssil Mágico"
	art_key     = "misseis_magicos"
	description = "No seu turno, dispare: 1 de dano direto a um herói à escolha."
	destroy_at_combat_end = true   # some quando o combate resolve

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["damage"] = damage
	return d

func apply_dict(data: Dictionary) -> void:
	super.apply_dict(data)
	damage = data.get("damage", damage)

# ── Habilidade ativada (disparo) — pertence ao token, não ao herói ───────────
func get_active_ability(player: Player, _opponent: Player) -> Dictionary:
	var missiles := player.count_tokens(token_id)
	if missiles <= 0:
		return {}
	return {
		"id": ABILITY_FIRE,
		"label": "Disparar Mísseis (%d)" % missiles,
		"cost": "FREE",
		"needs_target": true,
		"target_count": missiles,   # 1 alvo por míssil
		"token_id": token_id,       # token que acende como ativável
	}

func activate_ability(id: String, player: Player, opponent: Player, targets: Array) -> String:
	if id == ABILITY_FIRE:
		return _fire_missiles(player, opponent, targets)
	return ""

## Dispara 1 míssil por alvo em `targets` (1 de dano direto cada). Alvo pode ser
## herói aliado ou inimigo. Consome os mísseis disparados.
func _fire_missiles(player: Player, opponent: Player, targets: Array) -> String:
	var missiles := player.count_tokens(token_id)
	var shots := mini(missiles, targets.size())
	for i in shots:
		var target: Hero = targets[i]
		if target == null or not target.is_alive():
			continue
		# Provocar (Provocação da Valkar): dano direcionado ao time inimigo é puxado para o provocador.
		if target in opponent.heroes:
			target = opponent.redirect_target(target)
		var ctx := TurnContext.new()
		ctx.attacker_player = player
		ctx.defender_player = opponent if target in opponent.heroes else player
		ctx.attacker = player.active_hero
		ctx.defender = target
		# Muro de Aço (Valkar na linha de frente) protege os aliados de retaguarda; o
		# míssil é consumido mesmo assim (tiro desperdiçado contra a proteção).
		if ctx.defender_player.is_targeting_protected(target):
			continue
		var dealt := target.take_direct_damage(damage, ctx)  # respeita o escudo (Fluxo Reativo)
		if dealt > 0:
			GameBus.hero_damaged.emit(target, dealt)
			# Sobrecarga Arcana (Nox): míssil aplica *Marca* on-hit e recria 1 míssil.
			if player.missile_overcharge:
				player.marked_target = target
				player.marked_bonus = maxi(player.marked_bonus, 1)
				player.tokens.append(TokenMagicMissile.new())
	_consume(player, shots)
	return ""

func _consume(player: Player, count: int) -> void:
	var removed := 0
	var i := 0
	while i < player.tokens.size() and removed < count:
		if player.tokens[i].token_id == token_id:
			player.tokens.remove_at(i)
			removed += 1
		else:
			i += 1
