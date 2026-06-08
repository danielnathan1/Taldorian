# src/entities/card_effect_context.gd
class_name CardEffectContext
extends RefCounted

var source_player: Player
var opponent_player: Player
var source_card: Card
var played_from_arsenal: bool = false
var hero_was_hidden: bool = false

# Preenchidos APENAS na resolução de efeitos AFTER_COMBAT (resolve_after_combat).
# Perspectiva do source_player no combate do turno que acabou de resolver.
var damage_dealt: int = 0   # dano que o source causou ao oponente
var damage_taken: int = 0   # dano que o source sofreu
