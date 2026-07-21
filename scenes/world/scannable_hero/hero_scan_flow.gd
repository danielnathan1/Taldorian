# scenes/world/scannable_hero/hero_scan_flow.gd
# Fluxo COMPARTILHADO de rastreio de um ScannableHero: diálogo → minigame → custo → grant → popup.
# Fonte única usada pelo mundo aberto (world_root) e pela taverna do onboarding — garante que o
# scan seja IDÊNTICO nos dois lugares (mesmos minigames, diálogos e concessão via backend).
#
# NÃO mexe no scanner nem no lock de movimento — isso é responsabilidade de quem chama, pois difere
# entre o mundo (re-tentar ao falhar) e a taverna (sequência guiada). Também não recarrega inventário
# nem atualiza o HUD de ouro; devolve o resultado para o chamador aplicar.
#
# Uso:
#   var res := await HeroScanFlow.run(scannable_hero, ui_host, meu_ouro, player)
#   if res.granted: ... (deduzir res.gold_spent, recarregar inventário, re-habilitar scanner)
class_name HeroScanFlow
extends RefCounted

const DIALOGUE_SCENE     := preload("res://scenes/world/ui/dialogue/dialogue_box.tscn")
const REWARD_POPUP_SCENE := preload("res://scenes/world/ui/reward_popup/reward_popup.tscn")
const CONFIRM_PROMPT_SCENE := preload("res://scenes/world/ui/confirm_prompt/confirm_prompt.tscn")

## Roda o scan completo de UM ScannableHero. p_host = CanvasLayer/Node onde a UI é anexada
## (world_hud no mundo, UILayer na taverna). p_gold = ouro atual (gate de custo). p_player =
## opcional, para show_chat em caso de falha do backend. Retorna { granted, gold_spent }.
static func run(p_sh: ScannableHero, p_host: Node, p_gold: int = 0, p_player: Node = null) -> Dictionary:
	await _play_dialogue(p_host, p_sh.dialogue_id)

	# Gate 1: minigame (se houver). Perder aborta (fala de falha) — a menos que always_grant.
	if p_sh.minigame_id != "":
		var won: bool = await MinigameLauncher.run(p_host, p_sh.minigame_id, p_sh.minigame_config)
		if won:
			if p_sh.win_dialogue_id != "":
				await _play_dialogue(p_host, p_sh.win_dialogue_id)
		elif p_sh.always_grant:
			if p_sh.fail_dialogue_id != "":
				await _play_dialogue(p_host, p_sh.fail_dialogue_id)
		else:
			if p_sh.fail_dialogue_id != "":
				await _play_dialogue(p_host, p_sh.fail_dialogue_id)
			return { "granted": false, "gold_spent": 0 }

	# Gate 2: custo em ouro (se houver). Sem ouro ou recusou → aborta.
	if p_sh.cost > 0:
		if p_gold < p_sh.cost:
			if p_sh.fail_dialogue_id != "":
				await _play_dialogue(p_host, p_sh.fail_dialogue_id)
			return { "granted": false, "gold_spent": 0 }
		var paid: bool = await _confirm(p_host, "%s pede %d PO para se deixar rastrear. Pagar?" % [p_sh.hero_name, p_sh.cost])
		if not paid:
			if p_sh.fail_dialogue_id != "":
				await _play_dialogue(p_host, p_sh.fail_dialogue_id)
			return { "granted": false, "gold_spent": 0 }

	# Concede o herói no backend (idempotente). O custo é deduzido LÁ (autoritativo, atômico).
	var res: Dictionary = await ApiClient.claim_scanned_hero(p_sh.hero_key)
	if not res.get("ok", false):
		push_warning("[Scan] grant de '%s' FALHOU: %s" % [p_sh.hero_key, res.get("error", "")])
		if p_player != null and p_player.has_method("show_chat"):
			p_player.show_chat("O rastreio falhou...")
		return { "granted": false, "gold_spent": 0 }

	p_sh.mark_scanned()
	await _show_reward(p_host, p_sh.hero_art, p_sh.hero_name)
	return { "granted": true, "gold_spent": p_sh.cost }

# ── helpers de UI ────────────────────────────────────────────────────────────
static func _play_dialogue(p_host: Node, p_dialogue_id: String) -> void:
	var box := DIALOGUE_SCENE.instantiate()
	p_host.add_child(box)
	box.play(p_dialogue_id)
	await box.finished

static func _confirm(p_host: Node, p_message: String) -> bool:
	var prompt := CONFIRM_PROMPT_SCENE.instantiate()
	p_host.add_child(prompt)
	prompt.show_prompt(p_message)
	return await prompt.decided

static func _show_reward(p_host: Node, p_art: String, p_name: String) -> void:
	var popup := REWARD_POPUP_SCENE.instantiate()
	p_host.add_child(popup)
	popup.show_reward(p_art, p_name, "Novo herói rastreado!")
	await popup.closed
