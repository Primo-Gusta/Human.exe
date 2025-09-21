extends Control

@onready var skill_icon = $DetailsPanel/ContentVbox/HeaderVbox/SkillIcon
@onready var skill_name_label = $DetailsPanel/ContentVbox/HeaderVbox/SkillNameLabel
@onready var code_label = $DetailsPanel/ContentVbox/CodePanel/CodeLabel
@onready var upgrade1_button = $DetailsPanel/ContentVbox/UpgradesHBox/Upgrade1Button
@onready var upgrade2_button = $DetailsPanel/ContentVbox/UpgradesHBox/Upgrade2Button
@onready var close_button = $DetailsPanel/CloseButton

signal closed_popup

func _ready():
	close_button.pressed.connect(on_close_button_pressed)
	# Os botões de upgrade não precisam de lógica por enquanto, apenas visual
	upgrade1_button.pressed.connect(func(): print("Upgrade 1 clicado!"))
	upgrade2_button.pressed.connect(func(): print("Upgrade 2 clicado!"))

func setup_skill_details(icon_texture: Texture2D, name: String, code_string: String, upgrade1_text: String, upgrade2_text: String):
	skill_icon.texture = icon_texture
	skill_name_label.text = name
	code_label.text = code_string
	upgrade1_button.text = upgrade1_text
	upgrade2_button.text = upgrade2_text

	# Garante que o foco vá para o botão de fechar quando o popup abre
	close_button.grab_focus()

func on_close_button_pressed():
	print("Popup de detalhes fechado!")
	closed_popup.emit()
	queue_free() # Destrói o popup quando fechado
