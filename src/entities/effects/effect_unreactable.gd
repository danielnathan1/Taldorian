# Dominar (Fluxo Perfeito) — esta ação não pode ser reagida. Marca pending_cancel_reaction
# ANTES da janela de reação (pre_window), então o GameState não abre a janela ao oponente
# (ver game_state.gd: `if pending_cancel_reaction or _reactions_locked`).
class_name EffectUnreactable
extends CardEffect

func default_timing() -> int:
	return Timing.INSTANT

func pre_window_execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_cancel_reaction = true
