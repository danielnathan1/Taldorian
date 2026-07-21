# Fonte da Vida (Irena) — concede *Regeneração* de área: no fim dos próximos `turns` turnos,
# cura o time inteiro em `amount`. O tick fica em GameState._tick_team_regen (espelha a
# Queimadura, ao contrário). Ver Player.grant_team_regen.
class_name EffectTeamRegen
extends CardEffect

var _amount: int = 1
var _turns: int = 2

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)
	_turns  = params.get("turns", 2)

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.grant_team_regen(_amount, _turns)
