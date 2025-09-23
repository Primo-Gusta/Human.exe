extends Control

# --- REFERÊNCIAS DA CENA ---
@onready var skill_grid = $SkillsTabContainer/ContentVbox/MainContainer/VBoxContainer/Tabs/Scripts/ScrollContainer/SkillGrid
@onready var skill_details_panel = $SkillsTabContainer/ContentVbox/MainContainer/SkillDetailsPanel
@onready var skill_name_label = $SkillsTabContainer/ContentVbox/MainContainer/SkillDetailsPanel/SkillNameLabel
@onready var skill_description_label = $SkillsTabContainer/ContentVbox/MainContainer/SkillDetailsPanel/SkillDescriptionLabel
@onready var modify_button = $SkillsTabContainer/ContentVbox/MainContainer/SkillDetailsPanel/ModifyButton
@onready var equip_q_button = $SkillsTabContainer/ContentVbox/MainContainer/SkillDetailsPanel/EquipQButton
@onready var equip_e_button = $SkillsTabContainer/ContentVbox/MainContainer/SkillDetailsPanel/EquipEButton

# --- PRELOADS ---
var UpgradePopupScene = preload("res://Scenes/UI/SkillsDetailPopup.tscn")

# --- DADOS DAS HABILIDADES ---
# ATUALIZADO: Arraste seus arquivos SkillData.tres para este array no Inspetor.
@export var script_skills: Array[SkillData]

# --- VARIÁVEIS DE ESTADO ---
var player_node: Node
var selected_skill: SkillData = null

func _ready():
	skill_details_panel.visible = false
	modify_button.pressed.connect(_on_modify_pressed)
	equip_q_button.pressed.connect(_on_equip_q_pressed)
	equip_e_button.pressed.connect(_on_equip_e_pressed)

func initialize(p_player: Node):
	self.player_node = p_player
	populate_skill_grid()

func populate_skill_grid():
	for child in skill_grid.get_children():
		child.queue_free()
	
	for skill_data in script_skills:
		var skill_button = Button.new()
		skill_button.icon = skill_data.icon
		skill_button.custom_minimum_size = Vector2(128, 128)
		skill_button.pressed.connect(_on_skill_icon_pressed.bind(skill_data))
		skill_grid.add_child(skill_button)

func _on_skill_icon_pressed(skill_data: SkillData):
	selected_skill = skill_data
	
	skill_name_label.text = selected_skill.skill_name
	skill_description_label.text = selected_skill.description
	
	var next_recipe = find_next_available_recipe(selected_skill.recipes)
	modify_button.disabled = (next_recipe == null)
	
	skill_details_panel.visible = true

func _on_modify_pressed():
	if not selected_skill: return
	
	var next_recipe = find_next_available_recipe(selected_skill.recipes)
	if next_recipe:
		# Passa a lista completa de receitas da skill selecionada
		open_upgrade_popup(selected_skill.recipes, selected_skill.function_name, selected_skill.base_code)

func _on_equip_q_pressed():
	if is_instance_valid(player_node) and selected_skill:
		# Esta função ainda precisa ser criada no Player.gd
		# player_node.equip_skill(selected_skill, "q")
		print("Equipando ", selected_skill.skill_name, " no slot Q (Lógica a ser implementada no Player)")

func _on_equip_e_pressed():
	if is_instance_valid(player_node) and selected_skill:
		# player_node.equip_skill(selected_skill, "e")
		print("Equipando ", selected_skill.skill_name, " no slot E (Lógica a ser implementada no Player)")

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
