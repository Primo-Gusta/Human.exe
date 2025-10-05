extends Node2D

@onready var player = $Player
@onready var hud = $HUD
@onready var canvas_modulate = $CanvasModulate
@onready var player_camera = $Player/Camera2D

# Pré-carregar as cenas dos menus
var game_menus_scene = preload("res://Scenes/UI/GameMenus.tscn")
var pause_menu_scene = preload("res://Scenes/UI/PauseMenu.tscn")
const GameOverScreenScene = preload("res://Scenes/UI/GameOverScreen.tscn")

var current_game_menus_instance: CanvasLayer = null
var current_pause_menu_instance: CanvasLayer = null
var current_game_over_screen = null

var game_ready_for_input: bool = false # flag para ignorar inputs iniciais

func _ready() -> void:
	# Instanciar e configurar GameMenus
	if game_menus_scene:
		current_game_menus_instance = game_menus_scene.instantiate()
		add_child(current_game_menus_instance)
		current_game_menus_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		if current_game_menus_instance.has_signal("menu_closed_requested"):
			current_game_menus_instance.menu_closed_requested.connect(_on_game_menus_closed)
		current_game_menus_instance.visible = false

	# Instanciar e configurar PauseMenu
	if pause_menu_scene:
		current_pause_menu_instance = pause_menu_scene.instantiate()
		add_child(current_pause_menu_instance)
		current_pause_menu_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		if current_pause_menu_instance.has_signal("resume_game_requested"):
			current_pause_menu_instance.resume_game_requested.connect(_on_pause_menu_resumed_game)
		if current_pause_menu_instance.has_signal("quit_to_main_menu_requested"):
			current_pause_menu_instance.quit_to_main_menu_requested.connect(_on_pause_menu_quit_to_main_menu_requested)
		current_pause_menu_instance.visible = false
	
	hud.visible = true
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if is_instance_valid(player):
		hud.player = player
		if player.has_signal("player_died"):
			player.player_died.connect(Callable(self, "on_player_died"))
		if player.has_signal("health_updated"):
			player.health_updated.connect(Callable(hud, "update_health"))
		if player.has_signal("mana_updated"):
			player.mana_updated.connect(Callable(hud, "update_mana"))
		if player.has_signal("player_took_damage"):
			player.player_took_damage.connect(Callable(hud, "flash_screen"))
		if player.has_signal("skill_used"):
			player.skill_used.connect(Callable(hud, "start_cooldown_visual"))
		
		# CORREÇÃO: Conecta corretamente a HUD ao inventário
		if player.has_signal("active_item_changed"):
			player.active_item_changed.connect(Callable(self, "_on_player_active_item_changed"))
		if player.has_signal("inventory_updated"):
			player.inventory_updated.connect(Callable(self, "_on_player_inventory_updated"))
		
		if player.has_signal("equipped_skills_changed"):
			player.equipped_skills_changed.connect(Callable(hud, "update_equipped_skills"))

		# Sincronização inicial
		if is_instance_valid(hud):
			hud.update_equipped_skills(player.equipped_skill_q, player.equipped_skill_e)
			hud.update_active_item_display(player.inventory, player.active_item)

		if is_instance_valid(current_game_menus_instance):
			if current_game_menus_instance.has_method("initialize"):
				current_game_menus_instance.initialize(player)
			if current_game_menus_instance.has_method("on_player_inventory_updated"):
				current_game_menus_instance.on_player_inventory_updated(player.inventory, player.active_item)

	# Conectar inimigos presentes
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_signal("enemy_died"):
			enemy.enemy_died.connect(Callable(self, "on_enemy_died"))

	# Delay para habilitar inputs iniciais
	var t = get_tree().create_timer(0.12)
	t.timeout.connect(func ():
		game_ready_for_input = true
	)

	# Configura todos os spawners na cena
	for spawner in get_tree().get_nodes_in_group("spawners"):
		if spawner.has_method("set_player_camera"):
			spawner.set_player_camera(player_camera)

# --- Funções do jogador ---
func on_player_died() -> void:
	var tween = create_tween()
	tween.tween_property(canvas_modulate, "color", Color.BLACK, 1.0)
	await tween.finished

	if is_instance_valid(current_game_over_screen):
		return
		
	current_game_over_screen = GameOverScreenScene.instantiate()
	current_game_over_screen.restart_requested.connect(_on_restart_requested)
	add_child(current_game_over_screen)

func _on_restart_requested():
	if is_instance_valid(current_game_over_screen):
		current_game_over_screen.queue_free()
		current_game_over_screen = null
	get_tree().change_scene_to_file(scene_file_path)

func on_enemy_died() -> void:
	pass # lógica de XP, drops, etc.

# --- Input ---
func _unhandled_input(event) -> void:
	if not game_ready_for_input: return
	if not get_tree().paused and \
	   (current_game_menus_instance == null or not current_game_menus_instance.visible) and \
	   (current_pause_menu_instance == null or not current_pause_menu_instance.visible):
		if event.is_action_pressed("toggle_pause") and not event.is_echo():
			get_viewport().set_input_as_handled()
			toggle_pause_menu()
		elif event.is_action_pressed("toggle_game_menus") and not event.is_echo():
			get_viewport().set_input_as_handled()
			toggle_game_menus()

func toggle_game_menus() -> void:
	if current_game_menus_instance == null: return
	if current_pause_menu_instance != null and current_pause_menu_instance.visible: return
	var target_visibility: bool = not current_game_menus_instance.visible
	current_game_menus_instance.set_menu_state(target_visibility)
	get_tree().paused = target_visibility
	hud.visible = not target_visibility
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if target_visibility else Input.MOUSE_MODE_CAPTURED)

func _on_game_menus_closed() -> void:
	get_tree().paused = false
	hud.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func toggle_pause_menu() -> void:
	if current_pause_menu_instance == null: return
	if current_game_menus_instance != null and current_game_menus_instance.visible: return
	var target_visibility: bool = not current_pause_menu_instance.visible
	current_pause_menu_instance.set_menu_state(target_visibility)
	get_tree().paused = target_visibility
	hud.visible = not target_visibility
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if target_visibility else Input.MOUSE_MODE_CAPTURED)

func _on_pause_menu_resumed_game() -> void:
	get_tree().paused = false
	hud.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_pause_menu_quit_to_main_menu_requested():
	GameManager.go_to_main_menu()

# --- Atualizações de Inventário ---
func _on_player_active_item_changed(item_data: ItemData):
	if is_instance_valid(hud):
		hud.update_active_item_display(player.inventory, item_data)

func _on_player_inventory_updated(inventory: Dictionary, current_active_item: ItemData):
	if is_instance_valid(current_game_menus_instance):
		current_game_menus_instance.update_inventory(inventory, current_active_item)
	if is_instance_valid(hud):
		hud.update_active_item_display(inventory, current_active_item)
