# Fluxo Reativo — cria um escudo que previne N de dano em todos os heróis aliados vivos.
class_name EffectTeamDamageShield
extends CardEffect

var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	for h in ctx.source_player.heroes:
		if h.is_alive():
			h.damage_shield += _amount
	ctx.request_vfx("team_shield")
