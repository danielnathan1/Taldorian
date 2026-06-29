## scenes/vfx/arcane_fragments/arcane_fragments.gd
##
## VFX one-shot da magia "Fragmentos Arcanos" (herói Relicar/Feiticeiro).
## Leve sobre o board ao vivo (como o magic_missiles): os fragmentos NASCEM no
## token do Fragmento e o estouro/luz acontece no destino. Três variantes que
## escalam em intensidade, derivadas de um único tempo `t` por frame.
##
##   1 — Impacto  (END 2.55s): uma pedra em arco até o destino → DETONA.
##   2 — Colisão  (END 2.95s): duas pedras saem do token, colidem no destino → luz contida.
##   3 — Fusão    (END 3.30s): três pedras giram num anel que acelera → luz intensa + pilar.
##
## Wrapper fino (CanvasLayer). Toda a timeline e o desenho vivem no
## ArcaneFragmentsStage (Node2D), 100% procedural — nenhuma textura PNG externa.
## Não calcula gameplay: só encena.
##
## Uso (board.gd):
##   var fx := ArcaneFragmentsScene.instantiate()
##   add_child(fx)
##   fx.finished.connect(callback)               # auto-free logo após
##   fx.play(variant, token_global_pos, dest_global_pos)
class_name ArcaneFragments
extends CanvasLayer

## Emitido ao fim de toda a animação. O nó se auto-destrói em seguida.
signal finished

var _stage: ArcaneFragmentsStage = null


func _ready() -> void:
	layer = 55


## Inicia a encenação.
## effect ∈ {1,2,3}; origin = posição global do token; destination = global do clímax.
func play(effect: int, origin: Vector2, destination: Vector2) -> void:
	if _stage != null and is_instance_valid(_stage):
		_stage.queue_free()
	var stage := ArcaneFragmentsStage.new()
	stage.setup(self, clampi(effect, 1, 3), origin, destination)
	add_child(stage)
	_stage = stage


# Chamado pelo Stage no fim da timeline.
func _emit_finished() -> void:
	finished.emit()
	queue_free()
