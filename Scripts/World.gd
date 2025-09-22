extends Node2D

@onready var player = $Player
@onready var hud = $HUD
@onready var canvas_modulate = $CanvasModulate
@onready var player_camera = $Player/Camera2D

# Pré-carregar as cenas dos menus
var game_menus_scene = preload("res://Scenes/UI/GameMenus.tscn")
var pause_menu_scene = preload("res://Scenes/UI/PauseMenu.tscn")

var current_game_menus_instance: CanvasLayer = null
var current_pause_menu_instance: CanvasLayer = null

var game_ready_for_input: bool = false # flag para ignorar inputs iniciais

func _ready() -> void:
	# Conectar sinais do player/hud de forma explícita
	if is_instance_valid(player):
		if player.has_signal("player_died"):
			player.player_died.connect(Callable(self, "on_player_died"))
		if player.has_signal("health_updated"):
			player.health_updated.connect(Callable(hud, "update_health"))
		# NOVO: Conexão para a Mana
		if player.has_signal("mana_updated"):
			player.mana_updated.connect(Callable(hud, "update_mana"))
		if player.has_signal("player_took_damage"):
			player.player_took_damage.connect(Callable(hud, "flash_screen"))
		if player.has_signal("skill_q_cooldown_started"):
			player.skill_q_cooldown_started.connect(Callable(hud, "start_skill_q_cooldown_visual"))
		if player.has_signal("skill_e_cooldown_started"):
			player.skill_e_cooldown_started.connect(Callable(hud, "start_skill_e_cooldown_visual"))
		player.active_item_changed.connect(_on_player_active_item_changed)

	# Conectar inimigos já presentes
	var enemies_in_scene = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies_in_scene:
		if enemy.has_signal("enemy_died"):
			enemy.enemy_died.connect(Callable(self, "on_enemy_died"))

	print("World: Cena World.tscn carregada. Esperando 'start_game()' do MainMenu.")

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

func start_game() -> void:
	print("World: Executando 'start_game()' para inicializar GameMenus e PauseMenu...")

	# ... (código de instanciação dos menus permanece o mesmo)
	# Instanciar GameMenus se necessário
	if current_game_menus_instance == null:
		current_game_menus_instance = game_menus_scene.instantiate()
		add_child(current_game_menus_instance)
		current_game_menus_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		if current_game_menus_instance.has_signal("menu_closed_requested"):
			current_game_menus_instance.menu_closed_requested.connect(Callable(self, "_on_game_menus_closed"))
		player.inventory_updated.connect(Callable(self, "_on_player_inventory_updated"))
		current_game_menus_instance.request_set_active_item.connect(Callable(player, "set_active_item"))
		print("World: GameMenus instanciado e conectado.")
		# --- ADICIONE ESTA LINHA AQUI ---
		# Inicializa o GameMenus com a referência do jogador assim que ele é criado.
		current_game_menus_instance.initialize_with_player(player)
		# --- FIM DA ADIÇÃO ---
	current_game_menus_instance.visible = false


	# Instanciar PauseMenu se necessário
	if current_pause_menu_instance == null:
		current_pause_menu_instance = pause_menu_scene.instantiate()
		add_child(current_pause_menu_instance)
		current_pause_menu_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		if current_pause_menu_instance.has_signal("resume_game_requested"):
			current_pause_menu_instance.resume_game_requested.connect(Callable(self, "_on_pause_menu_resumed_game"))
		if current_pause_menu_instance.has_signal("quit_to_main_menu_requested"):
			current_pause_menu_instance.quit_to_main_menu_requested.connect(Callable(self, "_on_pause_menu_quit_to_main_menu_requested"))
		print("World: PauseMenu instanciado e conectado.")
	current_pause_menu_instance.visible = false


	# Estado inicial do jogo
	hud.visible = true
	# ATUALIZADO: Inicializa ambas as barras (Vida e Mana)
	if is_instance_valid(player) and is_instance_valid(hud):
		hud.set_max_health(player.max_health)
		hud.update_health(player.health)
		hud.set_max_mana(player.max_mana) # NOVO
		hud.update_mana(player.mana)       # NOVO
		hud.set_skill_mana_costs(player.skill_q_mana_cost, player.skill_e_mana_cost)

	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("World: Jogo inicializado e rodando. Menus escondidos.")

# --- As demais funções (on_player_died, on_enemy_died, _unhandled_input, etc.) permanecem exatamente as mesmas ---
# ... (código omitido para brevidade, pois não há alterações)

func on_player_died() -> void:
	print("O jogador foi corrompido! Game Over.")
	if not is_instance_valid(canvas_modulate):
		print("AVISO: Nó 'CanvasModulate' não encontrado. Fade-out não funcionará.")
		get_tree().reload_current_scene()
		return
	if not is_instance_valid(player_camera):
		print("AVISO: Nó 'Camera2D' no Player não encontrado. Zoom não funcionará.")
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(canvas_modulate, "color", Color.BLACK, 2.5)
	if is_instance_valid(player_camera):
		tween.tween_property(player_camera, "zoom", Vector2(1.8, 1.8), 2.5) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(1.0)
	tween.chain().tween_callback(get_tree().reload_current_scene)

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

func _on_pause_menu_quit_to_main_menu_requested() -> void:
	print("World: PauseMenu sinalizou para voltar ao MainMenu.")
	get_tree().paused = false
	var main_menu_path := "res://Scenes/UI/MainMenu.tscn"
	var main_menu_res = ResourceLoader.load(main_menu_path)
	if main_menu_res == null:
		push_warning("World: Não foi possível carregar " + main_menu_path + " (ResourceLoader.load retornou null). Verifique o caminho/arquivo.")
		return
	if not (main_menu_res is PackedScene):
		push_warning("World: O recurso carregado em " + main_menu_path + " não é um PackedScene.")
		return
	var main_menu_instance = main_menu_res.instantiate()
	if main_menu_instance == null:
		push_warning("World: Falha ao instanciar PackedScene '" + main_menu_path + "'.")
		return
	get_tree().root.add_child(main_menu_instance)
	queue_free()

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
