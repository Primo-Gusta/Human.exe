extends CharacterBody2D
class_name GuardianBoss

# --- SINAIS ---
signal boss_defeated

# --- CONFIGURAÇÃO ---
@export_group("Phase 1 Stats")
@export var phase_1_max_health: int = 3
@export_group("Corruption Stats")
@export var max_corruption_health: int = 3
@export_group("Stats")
@export var move_speed: float = 90.0
@export var dash_speed: float = 400.0
@export_group("AI Behaviour")
@export var attack_range: float = 50.0
@export var dash_range: float = 200.0
@export var dash_cooldown: float = 3.0

# --- ESTADOS DA IA ---
enum State {
	IDLE, CHASING, ATTACKING, STUNNED, TRANSITION, TIRED
}
var current_state = State.IDLE
var current_phase = 1

# --- VARIÁVEIS DE ESTADO ---
var health: int
var corruption_health: int
var player: CharacterBody2D = null
var can_dash: bool = true
var can_attack: bool = true
var minions_to_defeat: int = 0
var last_minion_position: Vector2 = Vector2.ZERO
var player_is_in_interaction_area: bool = false
var phase_3_attack_sequence_count: int = 0
const PHASE_3_ATTACKS_PER_CYCLE = 3
var phase_3_hits_to_stun: int = 0
const PHASE_3_REQUIRED_HITS = 3
var disabled_attacks: Array[String] = []
@export_group("Phase 3 Movement")
@export var phase_3_dash_duration: float = 0.4

var is_changing_state: bool = false
var is_in_long_attack: bool = false

var puzzles = {
	"security_routine_1": {
		"lines": [
			"FUNCTION grant_access(user_request):", "\tIF validate_request(user_request) == TRUE:",
			"\t\tRETURN core.access_granted", "\tELSE:", "\t\tDENY access AND PURGE(request)",
			"\tENDIF", "ENDFUNC"
		],
		"solution": [
			"FUNCTION grant_access(user_request):", "\tIF validate_request(user_request) == TRUE:",
			"\t\tRETURN core.access_granted", "\tELSE:", "\t\tDENY access AND PURGE(request)",
			"\tENDIF", "ENDFUNC"
		]
	}
}

# --- REFERÊNCIAS ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_points: Node2D = $AttackPoints
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer
@onready var melee_hurtbox_shape: CollisionShape2D = $MeleeHurtbox/CollisionShape2D
@onready var projectile_spawn_point: Marker2D = $AttackPoints/ProjectileSpawnPoint
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var interaction_area_shape: CollisionShape2D = $InteractionArea/CollisionShape2D
@export_group("Phase 3 Positions")
@export var phase_3_positions: Array[Marker2D]

# --- PRELOADS ---
const AreaAttackWaveScene = preload("res://Scenes/Enemies/AreaAttackWave.tscn")
const BossProjectileScene = preload("res://Scenes/Enemies/BossProjectile.tscn")
const CodePatchScene = preload("res://Scenes/Items/CodePatch.tscn")
const EnemyScene = preload("res://Scenes/Enemies/Enemy.tscn")
const BinaryWaveScene = preload("res://Scenes/Enemies/BinaryWave.tscn")
const CodeMinigameScene = preload("res://Scenes/UI/CodeMinigame.tscn")

func _ready():
	health = phase_1_max_health
	corruption_health = max_corruption_health
	add_to_group("enemies")
	$MeleeHurtbox.body_entered.connect(_on_melee_hurtbox_body_entered)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timer_timeout)
	dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timer_timeout)
	$InteractionArea.body_entered.connect(_on_interaction_area_body_entered)
	$InteractionArea.body_exited.connect(_on_interaction_area_body_exited)
	_change_state(State.IDLE)

func _physics_process(delta):
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player): return

	match current_state:
		State.IDLE: _state_idle()
		State.CHASING: _state_chasing(delta)
		State.ATTACKING: _state_attacking(delta)
		State.STUNNED: _state_stunned(delta)
		State.TRANSITION: _state_transition(delta)
		State.TIRED: _state_tired(delta)

	if current_phase == 2 and current_state == State.STUNNED and player_is_in_interaction_area:
		if Input.is_action_just_pressed("interact"):
			if is_instance_valid(player) and player.has_code_patch:
				_start_phase_3_transition()

# --- MÁQUINA DE ESTADOS E ANIMAÇÃO ---

func _change_state(new_state):
	if current_state == new_state: return

	var old_state = current_state
	current_state = new_state
	print("Boss mudou para o estado: ", State.keys()[new_state])

	var old_anim_group = _get_animation_group_for_state(old_state)
	var new_anim_group = _get_animation_group_for_state(new_state)

	if old_anim_group == new_anim_group:
		animated_sprite.play(new_anim_group)
	else:
		_play_state_change_animation()

func _get_animation_group_for_state(state):
	match state:
		State.IDLE, State.CHASING: return "idle"
		State.ATTACKING, State.TRANSITION: return "attack"
		State.STUNNED, State.TIRED: return "stunned"
	return "idle" # Fallback

func _play_state_change_animation():
	if not is_instance_valid(animated_sprite): return
	is_changing_state = true
	animated_sprite.play("state_change")
	await get_tree().create_timer(1.0).timeout # Espera 1 segundo
	if not is_instance_valid(self): return
	
	var final_anim = _get_animation_group_for_state(current_state)
	animated_sprite.play(final_anim)
	
	is_changing_state = false

func _state_idle():
	if is_changing_state: return
	velocity = Vector2.ZERO
	move_and_slide()
	if not can_attack: return

	if player.global_position.distance_to(global_position) > attack_range:
		_change_state(State.CHASING)
		return

	var attack_choice = randi_range(0, 2)
	match attack_choice:
		0: _execute_melee_attack()
		1: _execute_area_attack()
		2: _execute_ranged_attack()
	
	can_attack = false
	attack_cooldown_timer.wait_time = randf_range(1.5, 3.0)
	attack_cooldown_timer.start()

func _state_chasing(delta):
	if is_changing_state: return
	if player.global_position.distance_to(global_position) <= attack_range:
		_change_state(State.IDLE)
		velocity = Vector2.ZERO; move_and_slide()
		return

	if global_position.distance_to(player.global_position) > dash_range and can_dash:
		_execute_dash()
		return

	var direction = global_position.direction_to(player.global_position)
	velocity = direction * move_speed
	animated_sprite.flip_h = velocity.x < 0
	move_and_slide()

func _state_attacking(delta): velocity = Vector2.ZERO; move_and_slide()
func _state_stunned(delta): velocity = Vector2.ZERO; move_and_slide()
func _state_transition(delta): velocity = Vector2.ZERO; move_and_slide()
func _state_tired(delta): velocity = Vector2.ZERO; move_and_slide()

func _execute_dash():
	print("Boss usou o Dash da Fase 1!")
	can_dash = false
	_change_state(State.ATTACKING) # A sua lógica de animação já está aqui
	dash_cooldown_timer.start()
	
	var direction = global_position.direction_to(player.global_position)
	
	# --- EFEITO DE TELETRANSPORTE AQUI ---
	# 1. Esconde o sprite
	animated_sprite.visible = false
	
	# O Tween de movimento continua o mesmo
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(self, "global_position", global_position + direction * dash_range, dash_speed / 1000.0)
	
	# 2. Quando o tween terminar, reaparece e muda o estado
	tween.finished.connect(func():
		if is_instance_valid(self):
			animated_sprite.visible = true
			_change_state(State.CHASING)
	)

func _execute_melee_attack():
	_change_state(State.ATTACKING)
	animated_sprite.flip_h = player.global_position.x < global_position.x
	melee_hurtbox_shape.disabled = false
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self):
		melee_hurtbox_shape.disabled = true

func _execute_area_attack():
	_change_state(State.ATTACKING)
	is_in_long_attack = true
	var original_scale = self.scale
	var jump_scale = original_scale * 1.3
	
	var tween = create_tween(); tween.tween_property(self, "scale", jump_scale, 0.2); await tween.finished
	spawn_attack_wave(100.0, Color.BLACK)
	tween = create_tween(); tween.tween_property(self, "scale", original_scale, 0.4); await get_tree().create_timer(0.9).timeout
	if not is_instance_valid(self): return

	tween = create_tween(); tween.tween_property(self, "scale", jump_scale, 0.2); await tween.finished
	spawn_attack_wave(200.0, Color.YELLOW)
	tween = create_tween(); tween.tween_property(self, "scale", original_scale, 0.4); await get_tree().create_timer(0.9).timeout
	if not is_instance_valid(self): return
	
	tween = create_tween(); tween.tween_property(self, "scale", jump_scale, 0.2); await tween.finished
	spawn_attack_wave(300.0, Color.RED)
	tween = create_tween(); tween.tween_property(self, "scale", original_scale, 0.4); await get_tree().create_timer(0.9).timeout
	if not is_instance_valid(self): return
	
	is_in_long_attack = false
	if current_phase == 3: _decide_phase_3_action()
	else: _change_state(State.IDLE)

func _execute_ranged_attack():
	_change_state(State.ATTACKING)
	animated_sprite.flip_h = player.global_position.x < global_position.x
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(self): return
	var projectile = BossProjectileScene.instantiate()
	projectile.direction = global_position.direction_to(player.global_position)
	get_parent().add_child(projectile)
	projectile.global_position = projectile_spawn_point.global_position

func take_damage(amount, knockback_direction = Vector2.ZERO):
	if corruption_health <= 0: return
	if current_phase == 3 and current_state == State.TIRED:
		phase_3_hits_to_stun += 1
		if phase_3_hits_to_stun >= PHASE_3_REQUIRED_HITS: _expose_core()
		return
	if current_phase == 1:
		health -= amount
		if health <= 0:
			current_phase = 2
			_cancel_all_actions()
			call_deferred("_start_phase_2_transition")
		return

func _start_phase_2_transition():
	_change_state(State.TRANSITION)
	minions_to_defeat = 3
	for i in range(minions_to_defeat):
		var minion = EnemyScene.instantiate()
		var spawn_angle = (2 * PI / minions_to_defeat) * i
		var spawn_offset = Vector2.RIGHT.rotated(spawn_angle) * 150
		get_parent().add_child(minion)
		minion.global_position = global_position + spawn_offset
		minion.enemy_died.connect(_on_minion_died.bind(minion))

func _on_minion_died(minion_node):
	if is_instance_valid(minion_node): last_minion_position = minion_node.global_position
	minions_to_defeat -= 1
	if minions_to_defeat <= 0:
		_spawn_code_patch()
		_change_state(State.STUNNED)
		interaction_area_shape.disabled = false

func _start_phase_3_transition():
	if is_instance_valid(player): player.consume_code_patch()
	interaction_area_shape.set_deferred("disabled", true)
	player_is_in_interaction_area = false
	current_phase = 3
	_change_state(State.IDLE)
	phase_3_attack_sequence_count = 0
	can_attack = true
	attack_cooldown_timer.stop()
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(self): _decide_phase_3_action()

func _apply_core_damage():
	match corruption_health:
		3: disabled_attacks.append("TopPosition")
		2: disabled_attacks.append("BottomPosition")
	corruption_health -= 1
	if corruption_health <= 0: _die()
	else:
		_change_state(State.IDLE)
		phase_3_attack_sequence_count = 0
		can_attack = true
		attack_cooldown_timer.stop()
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(self): _decide_phase_3_action()

func _decide_phase_3_action():
	if is_changing_state: return
	if phase_3_attack_sequence_count >= PHASE_3_ATTACKS_PER_CYCLE: _start_tired_state()
	else:
		_change_state(State.ATTACKING)
		_execute_positional_dash()

func _execute_positional_dash():
	is_in_long_attack = true
	var available_positions = []
	for marker in phase_3_positions:
		if not marker.name in disabled_attacks: available_positions.append(marker)
	if available_positions.is_empty(): _start_tired_state(); return

	var target_marker = available_positions.pick_random()
	animated_sprite.visible = false
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_marker.global_position, phase_3_dash_duration)
	tween.finished.connect(func():
		if is_instance_valid(animated_sprite): animated_sprite.visible = true)
	await tween.finished
	if not is_instance_valid(self): return
	
	phase_3_attack_sequence_count += 1
	_execute_positional_attack()

func _execute_positional_attack():
	is_in_long_attack = true
	var closest_marker_name = ""
	var min_distance = INF
	for marker in phase_3_positions:
		var dist = global_position.distance_to(marker.global_position)
		if dist < min_distance:
			min_distance = dist; closest_marker_name = marker.name
	
	var original_position = global_position
	var wave_instance = null
	match closest_marker_name:
		"TopPosition", "BottomPosition":
			var recoil_tween = create_tween()
			var recoil_dir = -1 if global_position.x > get_viewport_rect().size.x / 2 else 1
			recoil_tween.tween_property(self, "global_position:x", global_position.x + (recoil_dir * 10), 0.1)
			await recoil_tween.finished
			wave_instance = spawn_binary_wave(closest_marker_name.to_lower().replace("position", ""))
		_: _execute_area_attack(); return

	if is_instance_valid(wave_instance): await wave_instance.wave_finished
	var return_tween = create_tween()
	return_tween.tween_property(self, "global_position", original_position, 0.1)
	await return_tween.finished
	
	is_in_long_attack = false
	if is_instance_valid(self): _decide_phase_3_action()

func _start_tired_state():
	_change_state(State.TIRED)
	phase_3_hits_to_stun = 0
	get_tree().create_timer(5.0).timeout.connect(func():
		if current_state == State.TIRED:
			phase_3_attack_sequence_count = 0
			_decide_phase_3_action()
	)

func _expose_core():
	_change_state(State.STUNNED)
	var minigame = CodeMinigameScene.instantiate()
	get_tree().root.add_child(minigame)
	minigame.puzzle_solved.connect(_apply_core_damage)
	minigame.call_deferred("start_puzzle", puzzles["security_routine_1"])

func _on_animation_finished():
	if animated_sprite.animation.begins_with("attack") and not is_in_long_attack:
		_change_state(State.IDLE)

func _on_attack_cooldown_timer_timeout(): can_attack = true
func _on_dash_cooldown_timer_timeout(): can_dash = true

func _on_melee_hurtbox_body_entered(body):
	if body.is_in_group("player"):
		body.take_damage(3, global_position.direction_to(body.global_position))
		melee_hurtbox_shape.set_deferred("disabled", true)

func _on_interaction_area_body_entered(body):
	if body.is_in_group("player"): player_is_in_interaction_area = true

func _on_interaction_area_body_exited(body):
	if body.is_in_group("player"): player_is_in_interaction_area = false

func spawn_attack_wave(radius: float, color: Color):
	var wave = AreaAttackWaveScene.instantiate()
	get_parent().add_child(wave)
	wave.global_position = global_position
	wave.activate(radius, color, 1.0, 0.3)

func spawn_binary_wave(spawn_location: String) -> Area2D:
	var wave = BinaryWaveScene.instantiate()
	var viewport_rect = get_viewport_rect()
	get_parent().add_child(wave)
	var spawn_y = viewport_rect.position.y if spawn_location == "top" else viewport_rect.position.y + (viewport_rect.size.y * 2 / 3)
	wave.global_position = Vector2(viewport_rect.position.x - viewport_rect.size.x, spawn_y)
	wave.setup_wave(viewport_rect.size.x, viewport_rect.size.y / 3, 2.0)
	return wave

func _spawn_code_patch():
	var patch = CodePatchScene.instantiate()
	get_parent().add_child(patch)
	patch.global_position = last_minion_position
	if is_instance_valid(player):
		patch.item_collected.connect(player._on_item_collected)

func _cancel_all_actions():
	for child in get_children():
		if child is Timer: child.stop()
	get_tree().call_group("attack_waves", "queue_free")

func _die():
	emit_signal("boss_defeated")
	queue_free()
