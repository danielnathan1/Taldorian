# scenes/ui/catalog/components/grid_lines.gd
# Desenha as linhas douradas que dividem uma página do fichário numa grade cols×rows.
# Fica sobre a página, alinhado ao GridContainer (mesmo rect), nos vãos entre as cartas.
extends Control

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")

var cols: int = 4
var rows: int = 4


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var col := Color(S.C_GOLD.r, S.C_GOLD.g, S.C_GOLD.b, 0.40)
	# Linhas internas (divisões entre cartas).
	for c in range(1, cols):
		var x := size.x * float(c) / float(cols)
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), col, 1.0)
	for r in range(1, rows):
		var y := size.y * float(r) / float(rows)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), col, 1.0)
	# Moldura externa da página.
	draw_rect(Rect2(Vector2.ZERO, size), Color(S.C_GOLD.r, S.C_GOLD.g, S.C_GOLD.b, 0.30), false, 1.0)
