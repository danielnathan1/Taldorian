# scripts/resources/style_resource.gd
class_name StyleResource extends Resource

@export var id: String
@export var category: String
@export var display_label: String
@export var preview_texture: Texture2D
@export var sprite_texture: Texture2D
@export var is_none: bool = false
@export var locked: bool = false
@export var supports_tint: bool = true
