# src/core/game_symbols.gd
## IDs estáveis para efeitos, cadeia de combate e `symbols_required` dos heróis.
## Cada carta pode ter 1 ou vários símbolos (`Array[String]` em ordem de jogo).
class_name GameSymbols
extends RefCounted

const FOGO := "fogo"
const TERRA := "terra"
const AGUA := "agua"
## Quarto elemento (ar/vento) — id local alinhado ao backend: "wind".
const AR := "wind"

const ALL: Array[String] = [FOGO, TERRA, AGUA, AR]

const DISPLAY: Dictionary = {
	FOGO: "Fogo",
	TERRA: "Terra",
	AGUA: "Água",
	AR: "Ar",
}

## De-para com o backend (taldorian-service), que usa nomes em inglês.
## fogo→FIRE · agua→WATER · terra→EARTH · ar→WIND
const TO_API: Dictionary = {
	FOGO: "FIRE",
	AGUA: "WATER",
	TERRA: "EARTH",
	AR: "WIND",
}

const FROM_API: Dictionary = {
	"FIRE": FOGO,
	"WATER": AGUA,
	"EARTH": TERRA,
	"WIND": AR,
}


## Converte um símbolo do backend ("FIRE") para o id local ("fogo").
static func from_api(api_symbol: String) -> String:
	return str(FROM_API.get(api_symbol.to_upper(), ""))


## Converte um id local ("fogo") para o símbolo do backend ("FIRE").
static func to_api(id: String) -> String:
	return str(TO_API.get(id, ""))


## Converte uma lista de símbolos do backend para ids locais (descarta inválidos).
static func from_api_list(api_symbols: Array) -> Array[String]:
	var out: Array[String] = []
	for s in api_symbols:
		var id := from_api(str(s))
		if id != "":
			out.append(id)
	return out


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
