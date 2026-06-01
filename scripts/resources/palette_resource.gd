# scripts/resources/palette_resource.gd
class_name PaletteResource extends Resource

@export var id: String
@export var display_label: String
@export var domain: String          # "hue" | "skin"
@export var swatches: Array[Color]
