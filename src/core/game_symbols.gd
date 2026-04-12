# src/core/game_symbols.gd
## IDs estáveis para efeitos, cadeia de combate e `symbols_required` dos heróis.
## Cada carta pode ter 1 ou vários símbolos (`Array[String]` em ordem de jogo).
class_name GameSymbols
extends RefCounted

const FOGO := "fogo"
const TERRA := "terra"
const AGUA := "agua"
## Quarto elemento: a lista pedida repetia "água"; aqui usamos ar (quarteto clássico).
const AR := "ar"

const ALL: Array[String] = [FOGO, TERRA, AGUA, AR]

const DISPLAY: Dictionary = {
	FOGO: "Fogo",
	TERRA: "Terra",
	AGUA: "Água",
	AR: "Ar",
}


static func is_valid(id: String) -> bool:
	return id in ALL


static func filter_valid(symbols: Array) -> Array[String]:
	var out: Array[String] = []
	for s in symbols:
		var id := str(s)
		if is_valid(id):
			out.append(id)
	return out


static func display_chain(symbols: Array[String]) -> String:
	if symbols.is_empty():
		return ""
	var parts: PackedStringArray = []
	for id in symbols:
		parts.append(str(DISPLAY.get(id, id)))
	return " · ".join(parts)
