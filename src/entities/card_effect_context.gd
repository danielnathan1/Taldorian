# src/entities/card_effect_context.gd
class_name CardEffectContext
extends RefCounted

var source_player: Player
var opponent_player: Player
var source_card: Card
var played_from_arsenal: bool = false
