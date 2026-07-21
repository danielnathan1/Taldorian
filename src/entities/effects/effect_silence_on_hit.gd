# Silêncio on-hit (Silêncio Profano) — se o herói ativo inimigo sofrer dano, fica
# *Silenciado*: perde skill de cadeia e habilidades ativadas por `turns` turnos.
# Ver Hero.apply_silence / is_silenced.
class_name EffectSilenceOnHit
extends CardEffect

var _turns: int = 1

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_turns = params.get("turns", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt <= 0:
		return
	var h := ctx.opponent_player.active_hero
	if h == null or not h.is_alive():
		return
	h.apply_silence(_turns)
