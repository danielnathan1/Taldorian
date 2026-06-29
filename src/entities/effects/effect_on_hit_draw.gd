# Exemplo de efeito AFTER_TURN condicional ao resultado do combate.
# "Se o seu herói ativo causou dano neste turno, compre N cartas."
# Demonstra o uso de ctx.damage_dealt, disponível só na resolução pós-combate.
class_name EffectOnHitDraw
extends CardEffect

var _amount: int = 1

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt > 0:
		ctx.source_player.draw_cards(_amount)
		ctx.request_vfx("draw")
