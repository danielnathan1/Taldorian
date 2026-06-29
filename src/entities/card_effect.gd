# src/entities/card_effect.gd
class_name CardEffect
extends RefCounted

## Momento em que o efeito resolve.
##   INSTANT        → resolve na hora em que a carta é jogada (antes da janela de reação).
##                    Usado por efeitos que influenciam a própria janela (ex.: cancelar reação).
##   AFTER_REACTION → resolve depois que a janela de reação da carta fecha (padrão).
##   AFTER_TURN   → não resolve na hora; é enfileirado e resolvido após o combate do turno,
##                    quando o resultado de dano já é conhecido (ver resolve_after_combat()).
enum Timing { INSTANT, AFTER_REACTION, AFTER_TURN }

## Quando ESTE efeito resolve. Definido pelo registry a partir de default_timing(),
## podendo ser sobrescrito por carta via campo "timing" no JSON.
var timing: int = Timing.AFTER_REACTION

## Spec de origem (id + params do JSON) que criou este efeito. Preenchido pelo
## CardEffectRegistry. Permite reserializar a carta com seus efeitos (snapshot de rede),
## para que `Card.effects` seja fiel também no cliente.
var spec: Dictionary = {}

## Timing padrão do efeito. Override em efeitos cujo timing é fixo
## (ex.: condicionais de combate são sempre AFTER_TURN, pois dependem do dano).
func default_timing() -> int:
	return Timing.AFTER_REACTION

func setup(_params: Dictionary) -> void:
	pass

# Executa imediatamente ao jogar a carta, antes da janela de reação ser aberta.
# Override apenas para efeitos que precisam influenciar a decisão de abrir a janela
# (ex.: cancelar reação). A maioria dos efeitos usa só execute().
func pre_window_execute(_ctx: CardEffectContext) -> void:
	pass

# Resolve quando a janela de reação da carta fecha (timing AFTER_REACTION/INSTANT).
# Efeitos com timing AFTER_TURN NÃO são chamados aqui — usam resolve_after_combat().
func execute(_ctx: CardEffectContext) -> void:
	pass

# Resolve após o combate do turno, em ordem FIFO de quando as cartas foram jogadas.
# Só é chamado para efeitos com timing == AFTER_TURN. O ctx carrega o resultado do
# combate deste turno (ctx.damage_dealt / ctx.damage_taken pela perspectiva do source).
func resolve_after_combat(_ctx: CardEffectContext) -> void:
	pass

# Disparado quando ESTA carta é descartada da mão pelo jogador (gatilho de descarte).
# Override apenas em efeitos com gatilho de descarte (ex.: Descarga Residual).
func on_discarded(_player: Player) -> void:
	pass
