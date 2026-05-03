# src/entities/effects/effect_pick_symbols.gd
# O jogador escolhe `count` símbolos que serão adicionados à carta fonte.
# Usado por "Manipulando Elementos" para escolher 2 elementos livremente.
class_name EffectPickSymbols
extends CardEffect

var _count: int = 2

func setup(params: Dictionary) -> void:
	_count = params.get("count", 2)

func execute(ctx: CardEffectContext) -> void:
	# Abre o overlay de escolha de símbolo.
	# after_reaction=true faz _on_reaction_window_closed() ser chamado após a escolha.
	GameState.begin_symbol_pick(
		ctx.source_player.player_index,
		ctx.source_card,
		_count,
		true
	)
