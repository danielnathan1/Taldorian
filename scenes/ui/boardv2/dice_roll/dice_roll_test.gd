## scenes/ui/boardv2/dice_roll/dice_roll_test.gd
## QA isolado da cena de dados: arraste para arremessar; os valores são sorteados
## localmente (no jogo de verdade vêm do servidor). Botão simula a vez do oponente.
extends Control

const DiceRollScene := preload("res://scenes/ui/boardv2/dice_roll/DiceRoll.tscn")

var _dice: DiceRoll

func _ready() -> void:
	_dice = DiceRollScene.instantiate()
	add_child(_dice)
	_dice.setup(0)               # somos o jogador 0 neste teste
	_dice.set_can_throw(true)
	_dice.thrown.connect(_on_thrown)
	_dice.first_player_chosen.connect(func(idx: int) -> void:
		_dice.set_status("Escolheu: jogador %d começa" % idx))

	var b := Button.new()
	b.text = "Rolar dado do oponente"
	b.position = Vector2(20.0, 680.0)
	b.custom_minimum_size = Vector2(200.0, 34.0)
	add_child(b)
	b.pressed.connect(func() -> void:
		_dice.play_roll(1, [randi_range(1, 6), randi_range(1, 6)], Vector2(0.0, -200.0)))

	# Auto-rola o oponente ao abrir, só para já ver os dados em movimento.
	await get_tree().create_timer(0.5).timeout
	_dice.play_roll(1, [3, 5], Vector2(0.0, -220.0))

func _on_thrown(dir: Vector2, force: float) -> void:
	# Simula o servidor: sorteia os valores e anima.
	var vals := [randi_range(1, 6), randi_range(1, 6)]
	_dice.play_roll(0, vals, dir)
	_dice.set_status("Você rolou %d + %d = %d" % [vals[0], vals[1], vals[0] + vals[1]])
	await get_tree().create_timer(1.8).timeout
	_dice.show_winner_choice(true)
