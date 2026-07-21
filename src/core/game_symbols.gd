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
## Quinto elemento (raio/relâmpago) — id local alinhado à arte: "lightning".
const RAIO := "lightning"
## Sexto elemento (trevas/dark) — id local alinhado ao backend: "DARK".
const TREVAS := "trevas"

const ALL: Array[String] = [FOGO, TERRA, AGUA, AR, RAIO, TREVAS]

const DISPLAY: Dictionary = {
	FOGO: "Fogo",
	TERRA: "Terra",
	AGUA: "Água",
	AR: "Ar",
	RAIO: "Raio",
	TREVAS: "Trevas",
}

## Ícone de cada elemento (fonte de verdade — usado em qualquer UI que mostre símbolos:
## HeroSlot, TextMarkup para {FIRE}/{DARK}/... inline no texto, etc.).
const ICON: Dictionary = {
	FOGO:  "res://assets/icons/elements/fire.png",
	TERRA: "res://assets/icons/elements/earth.png",
	AGUA:  "res://assets/icons/elements/water.png",
	AR:    "res://assets/icons/elements/wind.png",
	RAIO:  "res://assets/icons/elements/lightning.png",
	TREVAS: "res://assets/icons/elements/dark.png",
}


## Caminho do ícone de um id local ("fogo" → fire.png). "" se não houver.
static func icon_path(id: String) -> String:
	return str(ICON.get(id, ""))

## De-para com o backend (taldorian-service), que usa nomes em inglês.
## fogo→FIRE · agua→WATER · terra→EARTH · ar→WIND · raio→LIGHTNING
## NOTA: o backend ainda precisa reconhecer "LIGHTNING" (pendente).
const TO_API: Dictionary = {
	FOGO: "FIRE",
	AGUA: "WATER",
	TERRA: "EARTH",
	AR: "WIND",
	RAIO: "LIGHTNING",
	TREVAS: "DARK",
}

const FROM_API: Dictionary = {
	"FIRE": FOGO,
	"WATER": AGUA,
	"EARTH": TERRA,
	"WIND": AR,
	"LIGHTNING": RAIO,
	"DARK": TREVAS,
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
