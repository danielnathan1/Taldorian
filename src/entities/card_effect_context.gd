# src/entities/card_effect_context.gd
class_name CardEffectContext
extends RefCounted

var source_player: Player
var opponent_player: Player
var source_card: Card
var played_from_arsenal: bool = false
var hero_was_hidden: bool = false

# Preenchidos APENAS na resolução de efeitos AFTER_TURN (resolve_after_combat).
# Perspectiva do source_player no combate do turno que acabou de resolver.
var damage_dealt: int = 0   # dano que o source causou ao oponente
var damage_taken: int = 0   # dano que o source sofreu

# VFX pedidos pelo efeito QUANDO ele realmente age (drenados pelo GameState após a
# resolução e notificados aos clientes). Chamar dentro do ramo que aplica o efeito —
# assim condicionais (ex.: curar só se não tomou dano) não animam à toa.
# target_hero_idx: índice do herói alvo no source_player (-1 = ativo/padrão).
var requested_vfx: Array[Dictionary] = []

func request_vfx(key: String, target_hero_idx: int = -1) -> void:
	requested_vfx.append({ "key": key, "target_hero_idx": target_hero_idx })

# Movimento animado de uma carta específica (ex.: descarte com corte, ir ao deck).
# kind: "discard" (mão→centro→corte→cemitério) · "to_deck" (→ baralho). Drenado pelo
# GameState após a resolução e notificado aos clientes com o art_key da carta.
var requested_moves: Array[Dictionary] = []

func request_card_move(art_key: String, kind: String) -> void:
	requested_moves.append({ "art_key": art_key, "kind": kind })

# Buff de atk/def aplicado por este efeito → feixe "empower" (a animação default) no
# herói ativo, com os chips +ATK/+DEF. Chamar com o quanto o efeito somou.
var requested_empower: Array[Dictionary] = []

func request_empower(atk: int, def: int) -> void:
	requested_empower.append({ "atk": atk, "def": def })
