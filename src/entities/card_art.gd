# src/entities/card_art.gd
## Resolve a arte de uma carta pelo art_key, procurando nas subpastas por coleção.
## Fonte única de verdade do path de arte de carta — usada por Card, board e profile.
##
## Os art_key são globalmente únicos entre coleções, então basta procurar o PNG nas
## pastas conhecidas e usar a primeira que existir. A raiz (assets/card/) fica por ÚLTIMO,
## de propósito: durante a transição, imagens ainda soltas na raiz continuam funcionando.
## Nova expansão = +1 linha em _DIRS.
class_name CardArt
extends RefCounted

const _DIRS: Array[String] = [
	"res://assets/card/ecos_do_abismo/",
	"res://assets/card/taldorian_origins/",
	"res://assets/card/",
]

## Path do PNG da carta, ou "" se não encontrado em nenhuma pasta.
static func path_for(art_key: String) -> String:
	if art_key == "":
		return ""
	for d in _DIRS:
		var p := d + art_key + ".png"
		if ResourceLoader.exists(p):
			return p
	return ""

## Textura da carta, ou null se não encontrada.
static func texture_for(art_key: String) -> Texture2D:
	var p := path_for(art_key)
	if p != "":
		return load(p)
	return null
