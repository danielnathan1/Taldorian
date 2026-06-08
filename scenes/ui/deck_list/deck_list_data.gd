# scenes/ui/deck_list/deck_list_data.gd
# Dados auxiliares da DeckList. Sleeves/playmats vêm do CosmeticsStore (catálogo real);
# aqui fica só a cor de fundo dos chips de herói por classe.
class_name DeckListData

static var CLASS_COLOR: Dictionary = {
	"BARBARIAN": Color(0.42, 0.16, 0.10),
	"CLERIC":    Color(0.36, 0.30, 0.14),
	"ROGUE":     Color(0.24, 0.14, 0.34),
	"RANGER":    Color(0.16, 0.30, 0.18),
	"MONK":      Color(0.14, 0.28, 0.30),
	"GUARDIAN":  Color(0.20, 0.22, 0.30),
}


static func class_color(cls: String) -> Color:
	return CLASS_COLOR.get(cls, Color(0.16, 0.14, 0.22))
