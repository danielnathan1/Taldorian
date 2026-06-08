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
	passive_desc     = "No inicio de cada batalha se estiver na retaguarda, cause 1 de dano a um herói de sua escolha"
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
	ctx.defender = target
	var dmg := 1
	for h in ctx.defender_player.heroes:
		if h != ctx.defender:
			dmg = maxi(0, dmg - h.get_team_damage_reduction(ctx))
	if dmg > 0:
		target.take_damage(dmg, ctx)
		GameBus.hero_damaged.emit(target, dmg)
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
			ctx.defender = h
			var dmg := 1
			for ally in opponent.heroes:
				if ally != h:
					dmg = maxi(0, dmg - ally.get_aoe_damage_reduction(ctx))
			if dmg > 0:
				h.take_damage(dmg, ctx)
				GameBus.hero_damaged.emit(h, dmg)
	_skill_activated_this_battle = true
	GameBus.skill_activated.emit(self, skill_desc)
