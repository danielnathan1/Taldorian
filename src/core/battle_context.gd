# src/core/battle_context.gd
class_name BattleContext
extends RefCounted

# quem está brigando
var attacker: Hero
var defender: Hero
var attacker_player: Player
var defender_player: Player

# valores que os hooks podem modificar
var bonus_damage: int = 0
var bonus_block:  int = 0
var bonus_draw:   int = 0

# cadeia ativa no momento do combate (readonly pros hooks)
var chain: Array[String] = []

# resultado final — preenchido pelo CombatResolver após os hooks
var damage_dealt:  int = 0
var damage_taken:  int = 0
