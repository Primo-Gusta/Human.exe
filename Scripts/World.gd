extends Node2D

@onready var player = $Player
@onready var hud = $HUD
@onready var canvas_modulate = $CanvasModulate
@onready var player_camera = $Player/Camera2D
@onready var skill_q_icon = $SkillBarContainer/SkillSlotQ/SkillQ_Icon
@onready var skill_e_icon = $SkillBarContainer/SkillSlotE/SkillE_Icon

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
	if game_menus_scene: # Verifica se a cena está definida
		current_game_menus_instance = game_menus_scene.instantiate()
		add_child(current_game_menus_instance)
		current_game_menus_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		if current_game_menus_instance.has_signal("menu_closed_requested"):
			current_game_menus_instance.menu_closed_requested.connect(_on_game_menus_closed)
		current_game_menus_instance.visible = false # Começa escondido
		print("World: GameMenus instanciado e conectado.")

	# Instanciar e configurar PauseMenu
	if pause_menu_scene:
		current_pause_menu_instance = pause_menu_scene.instantiate()
		add_child(current_pause_menu_instance)
		current_pause_menu_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		if current_pause_menu_instance.has_signal("resume_game_requested"):
			current_pause_menu_instance.resume_game_requested.connect(_on_pause_menu_resumed_game)
		if current_pause_menu_instance.has_signal("quit_to_main_menu_requested"):
			current_pause_menu_instance.quit_to_main_menu_requested.connect(_on_pause_menu_quit_to_main_menu_requested)
		current_pause_menu_instance.visible = false # Começa escondido
		print("World: PauseMenu instanciado e conectado.")
	
	# Estado inicial do jogo
	hud.visible = true
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if is_instance_valid(player):
		hud.player = player # Apresenta o jogador à HUD
		if player.has_signal("player_died"):
			player.player_died.connect(Callable(self, "on_player_died"))
		if player.has_signal("health_updated"):
			player.health_updated.connect(Callable(hud, "update_health"))
		# NOVO: Conexão para a Mana
		if player.has_signal("mana_updated"):
			player.mana_updated.connect(Callable(hud, "update_mana"))
		if player.has_signal("player_took_damage"):
			player.player_took_damage.connect(Callable(hud, "flash_screen"))
		if player.has_signal("skill_used"):
			player.skill_used.connect(Callable(hud, "start_cooldown_visual"))
		if player.has_signal("active_item_change"):
			player.use_active_item.connect(Callable(hud, "update_active_item_display"))
		# ADICIONE esta nova conexão
		if player.has_signal("equipped_skills_changed"):
			player.equipped_skills_changed.connect(Callable(hud, "update_equipped_skills"))

		# --- SINCRONIZAÇÃO INICIAL (Ainda necessária para resolver o timing) ---
		if is_instance_valid(hud) and hud.has_method("update_equipped_skills"):
			hud.update_equipped_skills(player.equipped_skill_q, player.equipped_skill_e)
			
	if is_instance_valid(current_game_menus_instance):
		# Assumindo que o GameMenus tem uma função 'initialize' que chama a do SkillsMenu
		if current_game_menus_instance.has_method("initialize"):
			current_game_menus_instance.initialize(player)


	# Conectar inimigos já presentes
	var enemies_in_scene = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies_in_scene:
		if enemy.has_signal("enemy_died"):
			enemy.enemy_died.connect(Callable(self, "on_enemy_died"))

	var t = get_tree().create_timer(0.12)
	t.timeout.connect(func ():
		game_ready_for_input = true
		print("World: 'game_ready_for_input' agora é TRUE.")
	)
	
	# --- ADICIONE ESTE BLOCO DE CÓDIGO AO FINAL DA SUA FUNÇÃO _ready() ---
	# Configura todos os spawners na cena
	for spawner in get_tree().get_nodes_in_group("spawners"):
		if spawner.has_method("set_player_camera"):
			spawner.set_player_camera(player_camera)
			print("Referência da câmera entregue para o spawner: ", spawner.name)

# MODIFIQUE a sua função on_player_died
func on_player_died() -> void:
	print("O jogador foi corrompido! Game Over.")

	var tween = create_tween()
	tween.tween_property(canvas_modulate, "color", Color.BLACK, 1.0)
	await tween.finished
	
	# Se já houver uma tela de game over, não crie outra
	if is_instance_valid(current_game_over_screen):
		return
		
	current_game_over_screen = GameOverScreenScene.instantiate()
	current_game_over_screen.restart_requested.connect(_on_restart_requested)
	add_child(current_game_over_screen)
	
# MODIFIQUE a sua função _on_restart_requested
func _on_restart_requested():
	print("World: Pedido de reinício recebido. A recarregar a cena...")
	
	# --- A CORRECÇÃO ESTÁ AQUI ---
	# 1. Liberta a memória da tela de Game Over antes de mudar de cena
	if is_instance_valid(current_game_over_screen):
		current_game_over_screen.queue_free()
		current_game_over_screen = null # Limpa a referência
	
	# 2. Agora, recarrega a cena de forma segura
	get_tree().change_scene_to_file(scene_file_path)

func on_enemy_died() -> void:
	print("Um inimigo foi derrotado!")

func _unhandled_input(event) -> void:
	if not game_ready_for_input:
		return
	if not get_tree().paused and \
	   (current_game_menus_instance == null or not current_game_menus_instance.visible) and \
	   (current_pause_menu_instance == null or not current_pause_menu_instance.visible):
		if event.is_action_pressed("toggle_pause"):
			if event.is_pressed() and not event.is_echo():
				get_viewport().set_input_as_handled()
				toggle_pause_menu()
		elif event.is_action_pressed("toggle_game_menus"):
			if event.is_pressed() and not event.is_echo():
				get_viewport().set_input_as_handled()
				toggle_game_menus()

func toggle_game_menus() -> void:
	if current_game_menus_instance == null:
		print("World Erro: GameMenus não instanciado! Não pode ser toggled.")
		return
	if current_pause_menu_instance != null and current_pause_menu_instance.visible:
		print("World: Não pode abrir GameMenus enquanto PauseMenu está aberto.")
		return
	var target_visibility: bool = not current_game_menus_instance.visible
	current_game_menus_instance.set_menu_state(target_visibility)
	get_tree().paused = target_visibility
	hud.visible = not target_visibility
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if target_visibility else Input.MOUSE_MODE_CAPTURED)
	print("World: GameMenus " + ("aberto" if target_visibility else "fechado") + ", jogo " + ("pausado" if target_visibility else "retomado") + ".")

func _on_game_menus_closed() -> void:
	print("World: GameMenus sinalizou que foi fechado.")
	get_tree().paused = false
	if hud:
		hud.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func toggle_pause_menu() -> void:
	if current_pause_menu_instance == null:
		print("World Erro: PauseMenu não instanciado! Não pode ser toggled.")
		return
	if current_game_menus_instance != null and current_game_menus_instance.visible:
		print("World: Não pode abrir PauseMenu enquanto GameMenus está aberto.")
		return
	var target_visibility: bool = not current_pause_menu_instance.visible
	current_pause_menu_instance.set_menu_state(target_visibility)
	get_tree().paused = target_visibility
	hud.visible = not target_visibility
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if target_visibility else Input.MOUSE_MODE_CAPTURED)
	print("World: PauseMenu " + ("aberto" if target_visibility else "fechado") + ", jogo " + ("pausado" if target_visibility else "retomado") + ".")

func _on_pause_menu_resumed_game() -> void:
	print("World: PauseMenu sinalizou que o jogo foi resumido (via 'resume_game_requested').")
	get_tree().paused = false
	if hud:
		hud.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_pause_menu_quit_to_main_menu_requested():
	print("World: A pedir ao GameManager para voltar ao Main Menu.")
	GameManager.go_to_main_menu()

func _on_player_active_item_changed(item_data: ItemData):
	# Pega os dados mais recentes do inventário do jogador
	var current_inventory = player.inventory

	# Manda o GameMenus atualizar sua UI interna (o display do item selecionado)
	if is_instance_valid(current_game_menus_instance) and is_instance_valid(current_game_menus_instance.inventory_menu):
		current_game_menus_instance.inventory_menu.update_selected_item_display(item_data)
		
	# Manda a HUD principal atualizar o slot de item ativo
	if is_instance_valid(hud):
		hud.update_active_item_display(item_data, current_inventory)	
		
# E também precisamos atualizar a HUD quando o inventário mudar (ex: quantidade)
func _on_player_inventory_updated(inventory_data: Dictionary, current_active_item: ItemData):
	# O World agora distribui a informação para quem precisar
	
	# 1. Manda para o GameMenus
	if is_instance_valid(current_game_menus_instance):
		current_game_menus_instance.update_inventory(inventory_data, current_active_item)
	
	# 2. Manda para a HUD principal
	if is_instance_valid(hud):
		hud.update_active_item_display(current_active_item, inventory_data)
		
