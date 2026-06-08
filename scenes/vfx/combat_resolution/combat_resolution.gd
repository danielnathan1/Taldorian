## scenes/vfx/combat_resolution/combat_resolution.gd
##
## VFX one-shot da RESOLUÇÃO DE COMBATE — substitui o antigo overlay
## (scenes/ui/boardv2/combat_resolve). As duas cartas dos heróis ativos sobem
## ao centro, trocam golpes (Lâmina / Machado / Magia) e o resultado é encenado:
## popup de dano, queda de HP, flash, recuo e screen shake.
##
## Wrapper fino (CanvasLayer) — toda a timeline e o desenho vivem em
## CombatResolutionStage (Node2D), porta fiel de "Combat Resolution.html".
## Não calcula gameplay: recebe os valores já resolvidos e apenas os encena.
##
## Uso:
##   var fx := CombatResolutionScene.instantiate()
##   add_child(fx)
##   fx.hero_impacted.connect(cb)   # opcional — frame exato do impacto
##   fx.finished.connect(cb)        # auto-free logo após
##   var cfg := CombatResolution.Config.new()
##   ... preenche cfg ...
##   fx.play(cfg)
class_name CombatResolution
extends CanvasLayer

# ── Tipos de ataque (estética) ───────────────────────────────────────────────
enum AtkType { LAMINA, MACHADO, MAGIA }

# ── Sinais ───────────────────────────────────────────────────────────────────
## Emitido no frame exato do impacto de cada golpe. side = "ally" / "enemy".
signal hero_impacted(side: String, amount: int)
## Emitido ao fim de toda a animação. O nó se auto-destrói em seguida.
signal finished

# ── Config de entrada (montada por quem chama) ───────────────────────────────
## As cartas-duelistas são HeroSlot reais bindados a estes heróis, exibindo os
## status atuais (HP, ataque, defesa, classe, passiva, skill). O HP é capturado
## no setup (pré-golpe) e a barra anima a descida durante a encenação.
class Config extends RefCounted:
	var ally_hero:  Hero = null     # herói ativo do jogador local
	var enemy_hero: Hero = null     # herói ativo do oponente
	# Totais de combate já resolvidos (com turn_cards/bônus/penalidades). Se < 0,
	# o HeroSlot mostra os valores base do herói.
	var ally_atk:  int = -1
	var ally_def:  int = -1
	var enemy_atk: int = -1
	var enemy_def: int = -1
	var atk1_type: int = -1         # golpe do Aliado -> Inimigo (-1 = auto pela classe)
	var atk2_type: int = -1         # golpe do Inimigo -> Aliado (-1 = auto pela classe)
	var dmg1: int = 0               # dano que o Aliado causa no Inimigo
	var dmg2: int = 0               # dano que o Inimigo causa no Aliado


func _ready() -> void:
	layer = 55

## Inicia a encenação a partir de um Config já resolvido.
func play(p_cfg: Config) -> void:
	var stage := CombatResolutionStage.new()
	stage.setup(self, p_cfg)
	add_child(stage)

# Chamado pelo Stage no fim da timeline.
func _emit_finished() -> void:
	finished.emit()
	queue_free()

# Chamado pelo Stage no frame de impacto.
func _emit_impact(side: String, amount: int) -> void:
	hero_impacted.emit(side, amount)
