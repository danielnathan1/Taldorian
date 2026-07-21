class_name TextMarkup
extends Object

## Formatação de texto de regras do jogo (heróis, cartas, tokens).
##
## Duas marcações MANUAIS no texto-fonte (JSON de cartas, _init() dos heróis):
##
##   KEYWORD:  envolva com asteriscos simples — *exausto*, *Rosas Negras* — vira NEGRITO.
##   SÍMBOLO:  {FIRE} {WATER} {EARTH} {WIND} {LIGHTNING} {DARK} (nomes de API, ver GameSymbols)
##             viram o ÍCONE do elemento inline no texto.
##   PARÊNTESES: (texto) mantém os parênteses e coloca o conteúdo em ITÁLICO.
##             Requer o label ter `italics_font` (Palatino Italic) onde a base é Palatino.
##
## Fonte de verdade da sintaxe. Ver KEYWORDS.md.
##
## Uso:
##   RichTextLabel (bbcode):  label.text = TextMarkup.to_bbcode(desc, icon_px)
##   Label puro (sem bbcode): label.text = TextMarkup.strip(desc)
##   Auto-encolher p/ caber:  TextMarkup.fit_rich_label(label, base_px, min_px, compose)

const _KEYWORD := "\\*(.+?)\\*"        # *conteúdo* não-guloso (não cruza outro asterisco)
const _SYMBOL  := "\\{([A-Za-z]+)\\}"   # {NOME_DO_ELEMENTO}
const _PAREN   := "\\(([^()]+)\\)"      # (conteúdo entre parênteses, sem aninhar)

static var _kw_re: RegEx
static var _sym_re: RegEx
static var _paren_re: RegEx

static func _re(pattern: String, cache: RegEx) -> RegEx:
	if cache == null:
		cache = RegEx.new()
		cache.compile(pattern)
	return cache

## Converte marcações em BBCode. Para RichTextLabel com bbcode_enabled = true.
## icon_px: tamanho (px) dos ícones de símbolo; use o tamanho da fonte do label.
static func to_bbcode(text: String, icon_px: int = 16) -> String:
	if text == "":
		return text
	var out := text
	if out.contains("*"):
		_kw_re = _re(_KEYWORD, _kw_re)
		out = _kw_re.sub(out, "[b]$1[/b]", true)
	if out.contains("{"):
		out = _replace_symbols(out, icon_px)
	# Texto entre parênteses vira itálico (mantém os parênteses). Por último, para não
	# italizar colchetes de BBCode já inseridos (keywords/símbolos usam [] , não ()).
	if out.contains("("):
		_paren_re = _re(_PAREN, _paren_re)
		out = _paren_re.sub(out, "([i]$1[/i])", true)
	return out

## Remove/expande as marcações para exibição em Label puro (sem bbcode):
## keywords perdem o marcador; símbolos viram o nome do elemento ("Trevas").
static func strip(text: String) -> String:
	if text == "":
		return text
	var out := text
	if out.contains("*"):
		_kw_re = _re(_KEYWORD, _kw_re)
		out = _kw_re.sub(out, "$1", true)
	if out.contains("{"):
		out = _replace_symbols(out, 0)  # 0 → nome do elemento em vez de ícone
	return out

## Troca cada {NOME} pelo ícone do elemento (icon_px > 0) ou pelo nome (icon_px <= 0).
## {NOME} desconhecido é mantido literal (typo fica visível).
static func _replace_symbols(text: String, icon_px: int) -> String:
	_sym_re = _re(_SYMBOL, _sym_re)
	var out := text
	# Itera de trás pra frente para não invalidar os offsets ao substituir.
	var matches := _sym_re.search_all(out)
	for i in range(matches.size() - 1, -1, -1):
		var m := matches[i]
		var id := GameSymbols.from_api(m.get_string(1))
		if id == "":
			continue  # não é um elemento válido — deixa literal
		var replacement := ""
		if icon_px > 0:
			var path := GameSymbols.icon_path(id)
			if path == "":
				continue
			replacement = "[img=%dx%d]%s[/img]" % [icon_px, icon_px, path]
		else:
			replacement = str(GameSymbols.DISPLAY.get(id, id))
		out = out.substr(0, m.get_start()) + replacement + out.substr(m.get_end())
	return out


## Ajusta a fonte de um RichTextLabel (caixa fixa, scroll desligado) para o conteúdo
## caber na ALTURA visível: parte de [base_px] e reduz 1px por vez até caber ou atingir
## [min_px]. Encolhe SÓ se estourar. [compose] recebe o tamanho da fonte e devolve o
## BBCode (permite que ícones/símbolos acompanhem a fonte). Sem layout válido (size ainda
## 0), aplica base_px e sai — reconecte o sinal `resized` do label para refazer o ajuste
## quando a caixa ganhar tamanho.
static func fit_rich_label(label: RichTextLabel, base_px: int, min_px: int, compose: Callable) -> void:
	var px := maxi(min_px, base_px)
	while true:
		label.add_theme_font_size_override("normal_font_size", px)
		label.add_theme_font_size_override("bold_font_size", px)
		label.text = str(compose.call(px))
		if px <= min_px or not _rich_overflows(label):
			break
		px -= 1

## True se o conteúdo do RichTextLabel ultrapassa a altura da caixa. Sem layout válido
## (largura/altura ainda 0), retorna false (não encolhe — o ajuste é refeito no resized).
static func _rich_overflows(label: RichTextLabel) -> bool:
	if label.size.y <= 1.0 or label.size.x <= 1.0:
		return false
	return label.get_content_height() > label.size.y + 0.5
