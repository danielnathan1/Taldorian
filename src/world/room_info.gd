# src/world/room_info.gd
# Modelo de dados de uma sala de batalha listada na RoomLobby.
# A senha NUNCA trafega para o cliente — só `locked` indica que existe senha.
class_name RoomInfo extends RefCounted

const TYPE_CLASSICO := "classico"
const TYPE_FLASH    := "flash"

var id: int = 0
var room_name: String = ""
var game_type: String = TYPE_CLASSICO   # TYPE_CLASSICO | TYPE_FLASH
var players: int = 0
var capacity: int = 2
var locked: bool = false
## Sala de teste (criada por ADMIN). Marca a partida como debug, liberando o
## botão DEBUG no board (dar qualquer carta à mão). Ver GameState.is_debug_match().
var debug: bool = false


func is_full() -> bool:
	return players >= capacity


func type_label() -> String:
	return "Flash" if game_type == TYPE_FLASH else "Clássico"


func duplicate_info() -> RoomInfo:
	return from_dict(to_dict())


# ── Serialização para sync via RPC (senha NUNCA incluída) ─────────────────────
func to_dict() -> Dictionary:
	return {
		"id":        id,
		"room_name": room_name,
		"game_type": game_type,
		"players":   players,
		"capacity":  capacity,
		"locked":    locked,
		"debug":     debug,
	}


static func from_dict(p_d: Dictionary) -> RoomInfo:
	var r := RoomInfo.new()
	r.id        = int(p_d.get("id", 0))
	r.room_name = str(p_d.get("room_name", ""))
	r.game_type = str(p_d.get("game_type", TYPE_CLASSICO))
	r.players   = int(p_d.get("players", 0))
	r.capacity  = int(p_d.get("capacity", 2))
	r.locked    = bool(p_d.get("locked", false))
	r.debug     = bool(p_d.get("debug", false))
	return r
