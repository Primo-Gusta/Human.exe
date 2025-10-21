extends Control

@onready var initial_screen = $InitialScreen
@onready var main_options_screen = $MainOptionsScreen
@onready var start_game_button = $MainOptionsScreen/ButtonsContainer/StartGameButton
@onready var options_button = $MainOptionsScreen/ButtonsContainer/OptionsButton
@onready var quit_button = $MainOptionsScreen/ButtonsContainer/QuitButton
@onready var boss_button = $MainOptionsScreen/ButtonsContainer/BossButton
@onready var animation_player = $AnimationPlayer
@onready var world_scene_packed = preload("res://Scenes/Maps/World.tscn")

var intro_sequence_started = false

func _ready():
	# Conecta os sinais dos botões
	start_game_button.pressed.connect(on_start_game_button_pressed)
	options_button.pressed.connect(on_options_button_pressed)
	quit_button.pressed.connect(on_quit_button_pressed)
	boss_button.pressed.connect(on_boss_button_pressed)
	
	# Garante que o estado inicial está correto
	main_options_screen.visible = false
	initial_screen.visible = true
	# Garante que os botões comecem invisíveis para a animação de fade-in
	$MainOptionsScreen/ButtonsContainer.modulate.a = 0
	
	# Inicia a animação do cursor a piscar
	animation_player.play("CursorBlink")

func _unhandled_input(event):
	# Só reage ao input se a sequência ainda não começou
	if not intro_sequence_started and initial_screen.visible and event.is_action_pressed("ui_accept"):
		intro_sequence_started = true
		get_viewport().set_input_as_handled()
		# Chama a função que controla toda a sequência de animações
		_start_intro_sequence()

# Função assíncrona que controla a sequência de introdução
func _start_intro_sequence():
	# 1. Para o cursor de piscar
	animation_player.stop()
	
	# 2. Fade para preto
	animation_player.play("FadeToBlack")
	await animation_player.animation_finished

	# 3. Troca as telas enquanto a tela está preta
	initial_screen.visible = false
	main_options_screen.visible = true

	# 4. Fade de volta do preto
	animation_player.play("FadeFromBlack")
	await animation_player.animation_finished

	# 5. Animação de "digitar" o título
	animation_player.play("TypeTitle")
	await animation_player.animation_finished
	
	# 6. Fade-in dos botões
	animation_player.play("ButtonsFadeIn")
	await animation_player.animation_finished
	
	# 7. Foco no primeiro botão, agora que tudo está visível
	if start_game_button:
		start_game_button.grab_focus()

func on_start_game_button_pressed():
	print("MainMenu: A pedir ao GameManager para iniciar o jogo...")
	GameManager.start_new_game()
	
func on_boss_button_pressed():
	print("MainMenu: A pedir ao GameManager para iniciar o jogo...")
	GameManager.start_boss()

func on_options_button_pressed():
	print("MainMenu: Botão OPÇÕES pressionado!")
	# Lógica futura para o menu de opções

func on_quit_button_pressed():
	print("MainMenu: Botão SAIR pressionado!")
	get_tree().quit()
