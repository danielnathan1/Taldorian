# Fúria Incandescente (Poppy) — companheiro do discard_fire_for_attack. Se o herói ativo
# inimigo sofreu dano neste turno, recebe *Queimadura* de 1 por X turnos, onde X é o número
# de cartas de Fogo descartadas por esta carta (registrado em Player.pending_fire_discarded
# ao resolver o overlay de descarte). Resolve após o combate (dano conhecido).
class_name EffectBurnOnHitPerFire
extends CardEffect

var _amount: int = 1

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt <= 0:
		return
	var turns := ctx.source_player.pending_fire_discarded
	if turns <= 0:
		return
	var h := ctx.opponent_player.active_hero
	if h == null or not h.is_alive():
		return
	h.apply_burn(_amount, turns)
