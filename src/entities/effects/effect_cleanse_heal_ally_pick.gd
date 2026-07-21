# Toque Límpido (Irena) — abre o overlay de escolha de aliado; o herói escolhido é
# *Purificado* (remove Queimaduras) e curado em `amount`. Resolvido em GameState.rpc_submit_ally_pick
# (ação "cleanse_heal").
class_name EffectCleanseHealAllyPick
extends CardEffect

var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	GameState.begin_ally_pick(ctx.source_player.player_index, "cleanse_heal", _amount)
