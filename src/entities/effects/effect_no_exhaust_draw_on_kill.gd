# Devorar Essência — se este combate derrotou o herói ativo inimigo, o herói ativo não
# exausta ao fim do turno e você compra `draw` cartas. Ver Player.pending_prevent_exhaust.
class_name EffectNoExhaustDrawOnKill
extends CardEffect

var _draw: int = 1

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_draw = params.get("draw", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt <= 0:
		return
	var h := ctx.opponent_player.active_hero
	if h == null or h.state != Hero.State.DEFEATED:
		return
	ctx.source_player.pending_prevent_exhaust = true
	if _draw > 0:
		ctx.source_player.draw_cards(_draw)
		ctx.request_vfx("draw")
