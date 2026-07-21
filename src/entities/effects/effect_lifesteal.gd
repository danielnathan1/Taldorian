# Dreno (Ecos) — o herói ativo cura parte do dano causado neste combate. Resolve após o
# combate (dano conhecido). `amount` fixo > 0 cura esse valor on-hit; caso contrário cura
# round(dano * `fraction`) (mín. 1 quando houve dano). Bloqueado por *Ferida* (heal no-op).
class_name EffectLifesteal
extends CardEffect

var _fraction: float = 0.5
var _amount: int = 0

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_fraction = params.get("fraction", 0.5)
	_amount   = params.get("amount", 0)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt <= 0:
		return
	var h := ctx.source_player.active_hero
	if h == null or not h.is_alive():
		return
	var heal_amt := _amount if _amount > 0 else maxi(1, int(round(ctx.damage_dealt * _fraction)))
	h.heal(heal_amt)
	ctx.request_vfx("heal")
