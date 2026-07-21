# Sobrecarga Arcana (Nox) — até o fim do combate, cada Míssil Mágico que causa dano aplica
# *Marca* no alvo e recria 1 míssil. Só liga a flag; a lógica de disparo mora no token
# (TokenMagicMissile._fire_missiles), que lê Player.missile_overcharge.
class_name EffectMissileOvercharge
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.missile_overcharge = true
