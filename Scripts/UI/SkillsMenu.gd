extends Control

# --- REFERÊNCIAS DA CENA ---
@onready var attack_pulse_skill_icon = $SkillsTabContainer/ContentVBox/MainContainer/Tabs/Scripts/MainSkillsContainer/PulseSkillSlot/attack_pulse_skill_icon
@onready var pulse_modify_label = $SkillsTabContainer/ContentVBox/MainContainer/Tabs/Scripts/MainSkillsContainer/PulseSkillSlot/ModifyLabel

@onready var attack_loop_skill_icon = $SkillsTabContainer/ContentVBox/MainContainer/Tabs/Scripts/MainSkillsContainer/LoopSkillSlot/attack_loop_skill_icon
@onready var loop_modify_label = $SkillsTabContainer/ContentVBox/MainContainer/Tabs/Scripts/MainSkillsContainer/LoopSkillSlot/ModifyLabel

# --- PRELOADS ---
var UpgradePopupScene = preload("res://Scenes/UI/SkillsDetailPopup.tscn")

# --- DADOS DOS UPGRADES ---
# Arraste TODOS os arquivos .tres de receita para cada habilidade aqui no Inspetor
@export var pulse_skill_recipes: Array[UpgradeRecipeData]
@export var loop_skill_recipes: Array[UpgradeRecipeData]

# --- VARIÁVEIS DE ESTADO ---
var player_node: Node

func _ready():
	# Conecta os cliques dos ícones às funções de abertura do popup
	attack_pulse_skill_icon.pressed.connect(on_upgrade_pulse_pressed)
	attack_loop_skill_icon.pressed.connect(on_upgrade_loop_pressed)
	
	# Conecta os efeitos de hover (mouse)
	attack_pulse_skill_icon.mouse_entered.connect(_on_skill_mouse_entered.bind(attack_pulse_skill_icon, pulse_modify_label))
	attack_pulse_skill_icon.mouse_exited.connect(_on_skill_mouse_exited.bind(attack_pulse_skill_icon, pulse_modify_label))
	
	attack_loop_skill_icon.mouse_entered.connect(_on_skill_mouse_entered.bind(attack_loop_skill_icon, loop_modify_label))
	attack_loop_skill_icon.mouse_exited.connect(_on_skill_mouse_exited.bind(attack_loop_skill_icon, loop_modify_label))

# --- Funções para o Efeito de Hover ---
func _on_skill_mouse_entered(button: TextureButton, label: Label):
	button.modulate = Color(1, 1, 1, 0.5)
	label.visible = true

func _on_skill_mouse_exited(button: TextureButton, label: Label):
	button.modulate = Color(1, 1, 1, 1)
	label.visible = false

# --- Lógica de Abertura do Popup ---

func set_player_reference(p_player: Node):
	player_node = p_player

func on_upgrade_pulse_pressed():
	# Garanta que esta função esteja passando os argumentos corretos
	if not pulse_skill_recipes.is_empty():
		var skill_name = "func attack_pulse()"
		var base_code = """
var targets = get_nearby_enemies(area_range)
for target in targets:
ㅤtarget.take_damage(base_damage)
# UPGRADE 1
# UPGRADE 2"""
		open_upgrade_popup(pulse_skill_recipes, skill_name, base_code)
	else:
		print("Nenhuma receita de upgrade definida para a Habilidade Pulso.")

# ATUALIZADO: A função agora é muito mais simples
func on_upgrade_loop_pressed():
	if not pulse_skill_recipes.is_empty():
		# ATUALIZADO: Passa o nome da função e o código base como argumentos
		var skill_name = "func attack_loop()"
		var base_code = """
var projectile = Projectile.new()
projectile.setup(direction, initial_damage)
projectile.spawn()
# UPGRADE 1
# UPGRADE 2
"""
		open_upgrade_popup(pulse_skill_recipes, skill_name, base_code)
	else:
		print("Nenhuma receita de upgrade definida para a Habilidade Pulso.")


# ATUALIZADO: A função agora recebe os dados da habilidade
func open_upgrade_popup(recipes_to_build: Array[UpgradeRecipeData], skill_name: String, base_code: String):
	if not is_instance_valid(player_node):
		print("Erro: Referência do jogador não encontrada no SkillsMenu.")
		return
		
	var popup_instance = UpgradePopupScene.instantiate()
	add_child(popup_instance)
	
	# Chama a nova função do popup, passando TODOS os dados necessários
	popup_instance.open_with_recipes(recipes_to_build, player_node, skill_name, base_code)
	
	popup_instance.upgrade_compiled.connect(_on_upgrade_compiled)

func _on_upgrade_compiled(recipe_data: UpgradeRecipeData):
	print("Upgrade '", recipe_data.upgrade_name, "' compilado com sucesso no menu principal!")
