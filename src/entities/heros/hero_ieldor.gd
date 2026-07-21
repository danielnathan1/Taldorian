class_name HeroIeldor
extends Hero

func _init() -> void:
	art_key          = "hero_ieldor"
	hero_name        = "Ieldor"
	hero_class       = HeroClass.RANGER
	max_hp           = 9
	current_hp       = 9
	symbols_required.assign([GameSymbols.FOGO, GameSymbols.AR, GameSymbols.AR])
	skill_name       = "Chuva de Flechas"
	skill_desc       = "Causa 1 de dano a todos os heróis do oponente"
	passive_name     = "Retaguarda Precisa"
	passive_zone     = "backline"
	passive_desc     = "No início de cada batalha, cause 1 de dano a um herói de sua escolha"
	base_attack      = 1
	base_defense     = -1
	skill_animation  = "arrow_rain"

## Ieldor tem habilidade de retaguarda interativa — requer escolha de alvo pelo jogador.
func has_backline_ability() -> bool:
	return true

## Aplica 1 de dano ao herói escolhido pelo jogador.
## Retorna string vazia pois o popup já foi exibido ao confirmar o uso da habilidade.
func apply_backline_ability(player: Player, opponent: Player, target: Hero) -> String:
	var ctx := TurnContext.new()
	ctx.attacker_player = player
	ctx.defender_player = opponent if target in opponent.heroes else player
	ctx.attacker = self
	# Provocar (Provocação da Valkar): dano direcionado ao time inimigo é puxado para o provocador.
	if target in opponent.heroes:
		target = opponent.redirect_target(target)
	ctx.defender = target
	# Muro de Aço (Valkar na linha de frente) torna os aliados de retaguarda inalvejáveis.
	if ctx.defender_player.is_targeting_protected(target):
		return ""
	var dmg := 1
	for h in ctx.defender_player.heroes:
		if h != ctx.defender:
			dmg = maxi(0, dmg - h.get_team_damage_reduction(ctx))
	if dmg > 0:
		var dealt := target.take_direct_damage(dmg, ctx)  # respeita o escudo (Fluxo Reativo)
		if dealt > 0:
			GameBus.hero_damaged.emit(target, dealt)
	return ""

## Ativa: Ar, Ar, Água → causa 1 de dano a todos os heróis vivos do oponente
func on_skill_activated(player: Player) -> void:
	var opponent: Player = GameState.players[1 - player.player_index]
	var ctx := TurnContext.new()
	ctx.attacker_player = player
	ctx.defender_player = opponent
	ctx.attacker = self
	for h in opponent.heroes:
		if h.is_alive():
			# Muro de Aço protege os aliados de retaguarda; a linha de frente ainda é atingida.
			if opponent.is_targeting_protected(h):
				continue
			ctx.defender = h
			var dmg := 1
			for ally in opponent.heroes:
				if ally != h:
					dmg = maxi(0, dmg - ally.get_aoe_damage_reduction(ctx))
			if dmg > 0:
				var dealt := h.take_direct_damage(dmg, ctx)  # respeita o escudo (Fluxo Reativo)
				if dealt > 0:
					GameBus.hero_damaged.emit(h, dealt)
	_skill_activated_this_battle = true
	GameBus.skill_activated.emit(self, skill_desc)
