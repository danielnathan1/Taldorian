# src/entities/card_effect.gd
class_name CardEffect
extends RefCounted

func setup(_params: Dictionary) -> void:
	pass

# Executa imediatamente ao jogar a carta, antes da janela de reação ser aberta.
# Override apenas para efeitos que precisam influenciar a decisão de abrir a janela
# (ex.: cancelar reação). A maioria dos efeitos usa só execute().
func pre_window_execute(_ctx: CardEffectContext) -> void:
	pass

func execute(_ctx: CardEffectContext) -> void:
	pass
