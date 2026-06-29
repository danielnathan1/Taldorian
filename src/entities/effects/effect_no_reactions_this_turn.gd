# Calor Sufocante — nem você nem seu oponente podem jogar reações neste turno.
# Liga a trava de reações no GameState (nenhuma janela de reação abre até o fim do turno).
class_name EffectNoReactionsThisTurn
extends CardEffect

func execute(_ctx: CardEffectContext) -> void:
	GameState._reactions_locked = true
