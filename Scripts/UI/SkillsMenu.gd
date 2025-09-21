extends Control # SkillsMenu é filho de TabContainer, então Control é o correto

# SkillsMenu.gd
# Anteriormente: @onready var tabs = $VBoxContainer/MainContainer/Tabs
# Isso estava errado porque o primeiro MainContainer não tem VBoxContainer
# A nova hierarquia é SkillsMenu -> MainContainer -> ContentVBox -> SkillsTabContainer -> Tabs

@onready var tabs = $SkillsTabContainer/ContentVBox/MainContainer/Tabs
@onready var attack_pulse_skill_icon = $SkillsTabContainer/ContentVBox/MainContainer/Tabs/Scripts/MainSkillsContainer/AttackPulseSkillButton
@onready var attack_loop_skill_icon = $SkillsTabContainer/ContentVBox/MainContainer/Tabs/Scripts/MainSkillsContainer/AttackLoopSkillButton

var SkillDetailsPopupScene = preload("res://Scenes/UI/SkillsDetailPopup.tscn") # Caminho para a cena do popup (corrigido para "SkillDetailsPopup")

signal menu_closed_requested # Este sinal será usado pelo GameMenus para saber que o SkillsMenu foi fechado

func _ready():
	# Conecta os botões de ícone das habilidades
	attack_pulse_skill_icon.pressed.connect(func():
		show_skill_details(
			attack_pulse_skill_icon.texture_normal,
			"func attack_pulse()",
			"func attack_pulse():\n\tvar targets = get_nearby_enemies(area_range)\n\tfor target in targets:\n\t\ttarget.take_damage(base_damage)\n\t# UPGRADE 1\n\t# UPGRADE 2",
			"area_range = 150",
			"base_damage += 1"
		)
	)
	attack_loop_skill_icon.pressed.connect(func():
		show_skill_details(
			attack_loop_skill_icon.texture_normal,
			"func attack_loop()",
			"func attack_loop():\n\tvar projectile = Projectile.new()\n\tprojectile.setup(direction, initial_damage)\n\tprojectile.spawn()\n\t# UPGRADE 1\n\t# UPGRADE 2",
			"projectile.max_bounces += 1",
			"projectile.initial_damage += 1"
		)
	)

func _unhandled_input(event):
	# REMOVEMOS A LÓGICA DE FECHAMENTO AQUI. AGORA SERÁ GERENCIADA PELO GAMEMENUS.GD
	pass # Este menu não responde mais a um input de "toggle_skills_menu" diretamente

# Esta função será chamada pelo GameMenus para controlar a visibilidade e foco
func _set_menu_visibility(visible_status: bool):
	visible = visible_status
	if visible_status:
		# Garante o foco no primeiro item focalizável da aba de Scripts (primeiro ícone)
		if attack_pulse_skill_icon:
			attack_pulse_skill_icon.grab_focus()
	else:
		# Se for invisível, remove o foco
		release_focus()


func show_skill_details(icon_texture: Texture2D, name: String, code_string: String, upgrade1_text: String, upgrade2_text: String):
	var popup_instance = SkillDetailsPopupScene.instantiate()
	add_child(popup_instance) # Adiciona o popup como filho do SkillsMenu
	popup_instance.setup_skill_details(icon_texture, name, code_string, upgrade1_text, upgrade2_text)
	popup_instance.closed_popup.connect(func():
		print("Popup de habilidade fechou via sinal!")
		# Quando o popup fecha, o foco volta para o primeiro botão da aba atual
		if visible and attack_pulse_skill_icon:
			attack_pulse_skill_icon.grab_focus()
	)
	
	# Garante que o popup esteja no centro da tela
	popup_instance.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
