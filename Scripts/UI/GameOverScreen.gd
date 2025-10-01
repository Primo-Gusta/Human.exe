extends CanvasLayer

signal restart_requested

@onready var animation_player = $AnimationPlayer
var can_restart = false # Impede o reinício antes do texto aparecer

func _ready():
	# Inicia a animação de texto assim que a cena é criada
	animation_player.play("show_text")
	# Espera a animação terminar para permitir o reinício
	await animation_player.animation_finished
	can_restart = true

func _unhandled_input(event):
	if can_restart and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		# Pede ao GameManager para reiniciar
		GameManager.restart_current_level()
		# Não precisa mais de emitir sinal
