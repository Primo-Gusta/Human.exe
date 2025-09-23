extends Control
@onready var tabs = $SkillsTabContainer/ContentVBox/MainContainer/VBoxContainer/Tabs

# --- REFERÊNCIAS DA CENA ---
@onready var skill_grid = $SkillsTabContainer/ContentVBox/MainContainer/VBoxContainer/Tabs/Scripts/ScrollsContainer/SkillGrid
@onready var skill_details_panel = $SkillsTabContainer/ContentVBox/MainContainer/SkillDetailsPanel
@onready var skill_name_label = $SkillsTabContainer/ContentVBox/MainContainer/SkillDetailsPanel/SkillNameLabel
@onready var skill_description_label = $SkillsTabContainer/ContentVBox/MainContainer/SkillDetailsPanel/SkillDescriptsLabel
@onready var modify_button = $SkillsTabContainer/ContentVBox/MainContainer/SkillDetailsPanel/ModifyButton
@onready var equip_q_button = $SkillsTabContainer/ContentVBox/MainContainer/SkillDetailsPanel/EquipQButton
@onready var equip_e_button = $SkillsTabContainer/ContentVBox/MainContainer/SkillDetailsPanel/EquipEButton

# --- PRELOADS ---
var UpgradePopupScene = preload("res://Scenes/UI/SkillsDetailPopup.tscn")


# --- DADOS DAS HABILIDADES ---
# Arraste seus arquivos SkillData.tres para estes arrays no Inspetor
@export var script_skills: Array[SkillData]
@export var cybersecurity_skills: Array[SkillData]
@export var database_skills: Array[SkillData]

# --- VARIÁVEIS DE ESTADO ---
var player_node: Node
var selected_skill: SkillData = null

func _ready():
	skill_details_panel.visible = false # O painel começa invisível
	modify_button.pressed.connect(_on_modify_pressed)
	equip_q_button.pressed.connect(_on_equip_q_pressed)
	equip_e_button.pressed.connect(_on_equip_e_pressed)

func initialize(p_player: Node):
	self.player_node = p_player
	print("Iniciou SkillsMenu")
	# Popula todas as grades de habilidades
	populate_skill_grid(script_skills, "Scripts")
	populate_skill_grid(cybersecurity_skills, "Cybersecurity")
	populate_skill_grid(database_skills, "Database")
	
# Popula a grade de uma aba específica com os dados de skill fornecidos
func populate_skill_grid(skills_array: Array[SkillData], tab_name: String):
	# Encontra o GridContainer dentro da aba correta
	var skill_grid = tabs.get_node(tab_name).get_node("ScrollsContainer/SkillGrid")
	print("entrando em nó: ", skill_grid)
	
	# Limpa a grade antes de adicionar os novos ícones
	for child in skill_grid.get_children():
		print("child é:", child)
		child.queue_free()
	
	# Cria um botão para cada habilidade na lista
	for skill_data in skills_array:
		var skill_button = Button.new()
		print("butão é:", skill_button)
		skill_button.icon = skill_data.icon
		skill_button.custom_minimum_size = Vector2(128, 128)
		# Conecta o clique deste botão específico à função que mostra os detalhes
		skill_button.pressed.connect(_on_skill_icon_pressed.bind(skill_data))
		skill_grid.add_child(skill_button)
		
# Chamado quando um ícone de habilidade na grade é clicado
func _on_skill_icon_pressed(skill_data: SkillData):
	selected_skill = skill_data
	
	skill_name_label.text = selected_skill.skill_name
	skill_description_label.text = selected_skill.description
	
	# Habilita o botão "Modificar" apenas se houver receitas de upgrade para esta skill
	modify_button.disabled = selected_skill.recipes.is_empty()
	
	# A linha mais importante: torna o painel de detalhes visível
	skill_details_panel.visible = true
# --- Funções dos botões do painel de detalhes ---
func _on_modify_pressed():
	# (Lógica para abrir o popup de upgrade)
	if not selected_skill: return
	open_upgrade_popup(selected_skill.recipes, selected_skill.function_name, selected_skill.base_code)

func _on_equip_q_pressed():
	# (Lógica para equipar a skill)
	if is_instance_valid(player_node) and selected_skill:
		player_node.equip_skill(selected_skill, "q")

func _on_equip_e_pressed():
	# (Lógica para equipar a skill)
	if is_instance_valid(player_node) and selected_skill:
		player_node.equip_skill(selected_skill, "e")

# Esta função agora está completa
func find_next_available_recipe(recipe_list: Array[UpgradeRecipeData]) -> UpgradeRecipeData:
	if not is_instance_valid(player_node): return null
	for recipe in recipe_list:
		if not recipe.upgrade_effect_id in player_node.unlocked_upgrade_ids:
			return recipe
	return null

# Esta função agora está completa
func open_upgrade_popup(recipes_to_build: Array[UpgradeRecipeData], skill_name: String, base_code: String):
	if not is_instance_valid(player_node): return
		
	var popup_instance = UpgradePopupScene.instantiate()
	add_child(popup_instance)
	popup_instance.open_with_recipes(recipes_to_build, player_node, skill_name, base_code)
	popup_instance.upgrade_compiled.connect(_on_upgrade_compiled)

func _on_upgrade_compiled(recipe_data: UpgradeRecipeData):
	print("Upgrade '", recipe_data.upgrade_name, "' compilado com sucesso!")
	# Reavalia o estado do botão "Modificar"
	_on_skill_icon_pressed(selected_skill)
