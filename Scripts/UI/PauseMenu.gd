# Arquivo: res://Scripts/UI/PauseMenu.gd
extends CanvasLayer

# Sinais para o World.gd
signal resume_game_requested
signal quit_to_main_menu_requested

# Nós da cena
@onready var background_overlay: ColorRect = $BackgroundOverlay
@onready var buttons_container: VBoxContainer = $ButtonsContainer
@onready var resume_button: Button = $ButtonsContainer/ResumeButton
@onready var options_button: Button = $ButtonsContainer/OptionsButton
@onready var quit_button: Button = $ButtonsContainer/QuitToMainMenuButton

func _ready():
	# Começa invisível
	visible = false

	# Conecta os botões aos sinais
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# Opcional: conectar OptionsButton se você tiver menu de opções
	# options_button.pressed.connect(_on_options_pressed)

func set_menu_state(active: bool) -> void:
	visible = active

	if active:
		# Coloca foco no primeiro botão
		resume_button.grab_focus()
	else:
		# Libera foco recursivamente
		release_focus_recursive(self)

# Libera foco de todos os controles filhos
func release_focus_recursive(node: Node):
	if node is Control:
		if node.has_focus():
			node.release_focus()
	for child in node.get_children():
		release_focus_recursive(child)

# Botão Continuar
func _on_resume_pressed():
	set_menu_state(false)
	emit_signal("resume_game_requested")

# Botão Sair para o menu
func _on_quit_pressed():
	set_menu_state(false)
	emit_signal("quit_to_main_menu_requested")

# Opcional: botão de opções
# func _on_options_pressed():
#     print("Opções abertas")
