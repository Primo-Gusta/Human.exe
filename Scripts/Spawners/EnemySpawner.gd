extends Node2D
class_name EnemySpawner

@export var spawn_data: SpawnData
@export var min_spawn_radius: float = 50.0
@export var max_spawn_radius: float = 100.0
@export var max_spawn_attempts: int = 50 # Um número mais alto para garantir que encontramos um ponto

@onready var area_2d: Area2D = $Area2D
@onready var timer: Timer = $Timer
@onready var spawned_enemies_container: Node2D = $SpawnedEnemiesContainer

var spawned_enemies = []
var can_spawn = true
var player_in_area = null
var player_camera: Camera2D

func _ready():
	area_2d.body_entered.connect(_on_area_2d_body_entered)
	area_2d.body_exited.connect(_on_area_2d_body_exited)
	timer.timeout.connect(_on_timer_timeout)

	if spawn_data:
		timer.wait_time = spawn_data.respawn_cooldown
	else:
		print("AVISO: Spawner '", self.name, "' não tem um SpawnData definido!")

func set_player_camera(camera: Camera2D):
	self.player_camera = camera

# --- FUNÇÃO CORRIGIDA E SIMPLIFICADA ---
func find_spawn_position() -> Vector2:
	if not is_instance_valid(player_camera):
		print("ERRO: Spawner não tem referência da câmera do jogador.")
		return Vector2.INF

	# Pega o estado do mundo físico 2D
	var space_state = get_world_2d().direct_space_state
	var attempts = 0
	
	# Calcula a área da câmara (o seu código para isto já está perfeito)
	var viewport_size = get_viewport().get_visible_rect().size
	var visible_world_size = viewport_size / player_camera.zoom
	var camera_top_left = player_camera.global_position - (visible_world_size / 2)
	var camera_world_rect = Rect2(camera_top_left, visible_world_size)
	
	# Loop de tentativas
	while attempts < max_spawn_attempts:
		attempts += 1
		
		# 1. Gera um ponto aleatório ao redor do spawner
		var random_angle = randf_range(0, TAU)
		var random_radius = randf_range(min_spawn_radius, max_spawn_radius)
		var spawn_point_world = global_position + Vector2.RIGHT.rotated(random_angle) * random_radius
		
		# 2. Primeira verificação: O ponto está fora do ecrã?
		if camera_world_rect.has_point(spawn_point_world):
			continue # Se estiver no ecrã, salta para a próxima tentativa

		# 3. Segunda verificação (A mais importante): O ponto está num local vazio?
		var query = PhysicsPointQueryParameters2D.new()
		query.position = spawn_point_world
		# Opcional: Se as suas paredes estiverem numa camada de física específica, pode optimizar aqui
		# query.collision_mask = 1 
		
		var result = space_state.intersect_point(query)

		# Se 'result' estiver vazio, significa que não há colisões. É um ponto válido!
		if result.is_empty():
			print("Spawner: Posição válida encontrada na tentativa ", attempts)
			return spawn_point_world # Retorna a posição válida e sai da função

	# Se o loop terminar sem sucesso, retorna o valor de falha
	print("AVISO: Spawner desistiu após ", max_spawn_attempts, " tentativas.")
	return Vector2.INF
	
# --- O resto do script permanece o mesmo ---
func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		player_in_area = body
		try_to_spawn()

func _on_area_2d_body_exited(body):
	if body.is_in_group("player"):
		player_in_area = null

func try_to_spawn():
	if player_in_area and can_spawn:
		spawn_enemies()

func spawn_enemies():
	if not spawn_data or spawn_data.enemy_scenes.is_empty(): return
	if not is_instance_valid(player_in_area): return
	can_spawn = false
	print("Spawner ativado! Gerando inimigos...")
	for i in range(spawn_data.max_enemies_on_screen):
		var enemy_scene = spawn_data.enemy_scenes.pick_random()
		if not enemy_scene: continue
		var enemy_instance = enemy_scene.instantiate()
		call_deferred("add_enemy_to_scene", enemy_instance)

func add_enemy_to_scene(enemy_instance):
	var spawn_pos = find_spawn_position()
	if spawn_pos == Vector2.INF:
		enemy_instance.queue_free()
		print("AVISO: Não foi possível encontrar uma posição de spawn válida.")
		if spawned_enemies.is_empty():
			can_spawn = true
		return
	spawned_enemies_container.add_child(enemy_instance)
	enemy_instance.global_position = spawn_pos
	spawned_enemies.append(enemy_instance)
	enemy_instance.enemy_died.connect(_on_enemy_died.bind(enemy_instance))

func _on_enemy_died(enemy_instance):
	if enemy_instance in spawned_enemies:
		spawned_enemies.erase(enemy_instance)
	if spawned_enemies.is_empty():
		print("Cooldown do spawner iniciado.")
		timer.start()

func _on_timer_timeout():
	can_spawn = true
	print("Cooldown do spawner terminado.")
	try_to_spawn()
