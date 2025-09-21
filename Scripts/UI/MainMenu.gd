# Arquivo: res://Scripts/UI/MainMenu.gd
extends Control

@onready var initial_screen = $InitialScreen
@onready var main_options_screen = $MainOptionsScreen
@onready var start_game_button = $MainOptionsScreen/ButtonsContainer/StartGameButton
@onready var options_button = $MainOptionsScreen/ButtonsContainer/OptionsButton
@onready var quit_button = $MainOptionsScreen/ButtonsContainer/QuitButton

# O World será carregado diretamente, então não precisamos mais de um sinal externo para ele.
# signal start_game_requested 
# signal options_menu_requested # Manter se for usar internamente no MainMenu para outras telas de opção.

@onready var world_scene_packed = preload("res://Scenes/World.tscn") # Adiciona o preload para o World

func _ready():
	# Conecta os botões
	start_game_button.pressed.connect(on_start_game_button_pressed)
	options_button.pressed.connect(on_options_button_pressed)
	quit_button.pressed.connect(on_quit_button_pressed)

	# Garante que o foco inicial esteja no Start Game Button quando as opções aparecerem
	start_game_button.grab_focus() # Isso ainda é relevante para a tela de opções

	# Para testes, se você quiser que o MainOptionsScreen apareça direto para clicar.
	# initial_screen.visible = false
	# main_options_screen.visible = true


func _unhandled_input(event):
	if initial_screen.visible and event.is_action_pressed("ui_accept"):
		initial_screen.visible = false
		main_options_screen.visible = true
		get_viewport().set_input_as_handled()
		print("Entrou no menu principal!")
		# Opcional: Se quiser dar foco a algum botão ao entrar na MainOptionsScreen
		if start_game_button:
			start_game_button.grab_focus()


func on_start_game_button_pressed():
	print("MainMenu: Botão COMEÇAR JOGO pressionado! Carregando World...")
	# 1. Instanciar a cena do World
	var world_instance = world_scene_packed.instantiate()

	# 2. Adicionar o World à árvore de cena (como filho da raiz da árvore)
	get_tree().root.add_child(world_instance)

	# 3. Chamar a função de inicialização do World
	if world_instance.has_method("start_game"):
		world_instance.start_game()
	else:
		print("MainMenu Erro: A cena World.tscn não possui a função 'start_game()'.")

	# 4. Remover o MainMenu da árvore de cena
	queue_free() # Remove o MainMenu da memória e da tela.

func on_options_button_pressed():
	print("MainMenu: Botão OPÇÕES pressionado!")
	# Por enquanto, apenas imprime. Futuramente, pode emitir um sinal para um menu de opções,
	# ou carregar uma cena de opções.

func on_quit_button_pressed():
	print("MainMenu: Botão SAIR pressionado!")
	get_tree().quit() # Sai do jogo
