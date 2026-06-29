# Florescer Eterno — após o combate, cura N todos os heróis aliados vivos e, para cada
# aliado efetivamente curado, causa 1 de dano ao herói ativo inimigo.
# v1: dano concentrado no herói ativo inimigo. TODO: distribuir entre heróis inimigos
# aleatórios, conforme o texto da carta.
class_name EffectHealAllAlliesReflect
extends CardEffect

var _amount: int = 1

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	var healed := 0
	for h in ctx.source_player.heroes:
		if h.is_alive():
			var before := h.current_hp
			h.heal(_amount)
			if h.current_hp > before:
				healed += 1
	ctx.request_vfx("heal_all")
	if healed > 0:
		GameState._deal_direct_damage(ctx.opponent_player.player_index, healed)
