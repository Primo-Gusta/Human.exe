extends CharacterBody2D

@export var speed = 75
var health = 3 # Vida inicial para um Worm (pode ser ajustado)
var max_health = 3
signal health_updated(current_health)
signal enemy_died

var player = null
var is_dead = false
var attack_range = 40.0
var is_attacking = false
var knockback_strength = 80.0
var is_in_knockback = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var detection_area = $DetectionArea
@onready var detection_area_shape = $DetectionArea/CollisionShape2D
@onready var hitbox_shape = $Hitbox/CollisionShape2D
@onready var attack_cooldown = $AttackCooldown
@onready var attack_animation_player = $AttackAnimationPlayer
@onready var attack_indicator = $AttackIndicator

var last_direction = Vector2.ZERO

# --- NOVO: Variáveis para a lógica de divisão ---
@export var splits_into = 2 # Quantos worms menores este worm irá gerar
@export var small_worm_health_multiplier = 0.5 # Saúde dos worms menores (ex: 50% do original)
@export var small_worm_scale_multiplier = 1.05 # Escala dos worms menores (ex: 70% do original)
@export var small_worm_speed_multiplier = 1.2 # Velocidade dos worms menores (ex: 120% do original)
var is_small_worm = false # Flag para saber se este é um worm "filho"

func _ready():
	draw_attack_indicator_circle()
	health_updated.emit(health)

	# NOVO: Ajusta o tamanho e velocidade se for um worm pequeno
	if is_small_worm:
		scale *= small_worm_scale_multiplier
		health = int(max_health * small_worm_health_multiplier)
		max_health = health # Atualiza max_health para a HUD
		speed *= small_worm_speed_multiplier
		# Opcional: ajustar cor para diferenciar visualmente (sem arte nova)
		animated_sprite.modulate = Color(1.0, 0.7, 0.7, 1.0) # Um tom avermelhado
		# Ou: animated_sprite.self_modulate = Color(...) para afetar apenas o sprite

func draw_attack_indicator_circle():
	var radius = attack_range
	var num_points = 32
	var points = []
	for i in range(num_points + 1):
		var angle = (2 * PI * i) / num_points
		var point = Vector2(cos(angle), sin(angle)) * radius
		points.append(point)
	attack_indicator.points = points

func _physics_process(delta):
	if is_dead:
		return

	if is_attacking:
		if is_in_knockback:
			velocity = velocity.move_toward(Vector2.ZERO, speed * 2 * delta)
			move_and_slide()
		return

	if is_in_knockback:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 2 * delta)
		move_and_slide()
		update_animation()
		return

	if detection_area.get_overlapping_bodies().has(player):
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player > attack_range:
			var direction = (player.global_position - global_position).normalized()
			velocity = direction * speed
			last_direction = direction
		else:
			velocity = Vector2.ZERO
			if attack_cooldown.is_stopped():
				attack()
	else:
		player = null
		velocity = Vector2.ZERO

	move_and_slide()
	update_animation()

func take_damage(amount, knockback_direction = Vector2.ZERO):
	if is_dead:
		return
	health -= amount
	health_updated.emit(health)

	is_in_knockback = true
	velocity = knockback_direction * knockback_strength
	get_tree().create_timer(0.2).timeout.connect(on_knockback_finished)

	if health <= 0:
		call_deferred("die")

func on_knockback_finished():
	is_in_knockback = false

func update_animation():
	if is_attacking:
		return
	if velocity.length() > 0.1:
		if is_in_knockback:
			animated_sprite.play("idle")
		else:
			if abs(velocity.x) > abs(velocity.y):
				animated_sprite.play("walk")
				animated_sprite.flip_h = velocity.x < 0
			else:
				animated_sprite.play("walk_down" if velocity.y > 0 else "walk_up")
	else:
		animated_sprite.play("idle")

# --- NOVO: Função die do Worm com lógica de divisão ---
func die():
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	is_in_knockback = false

	collision_shape.disabled = true
	detection_area_shape.disabled = true
	animated_sprite.play("dead")

	# --- Lógica de DIVISÃO do Worm ---
	if not is_small_worm: # Apenas worms "pais" se dividem
		var WormScene = load("res://scenes/worm.tscn") # Caminho para a cena do worm
		for i in range(splits_into):
			var new_worm = WormScene.instantiate()
			get_parent().add_child(new_worm)
			new_worm.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10)) # Pequeno offset
			new_worm.is_small_worm = true # Marca como "filho"
			new_worm.player = player # Passa a referência do player para os filhos

			# Opcional: para o mundo reagir aos novos worms
			# se o World.gd tem um sinal para "enemy_spawned"
			# get_parent().emit_signal("enemy_spawned", new_worm) 
	# --- Fim da Lógica de DIVISÃO ---

	enemy_died.emit() # Sinaliza ao mundo que este inimigo morreu

	var tween = create_tween()
	var num_flashes = 7
	for i in range(num_flashes):
		var flash_duration = 0.2 * (1.0 - float(i) / num_flashes)
		tween.tween_property(animated_sprite, "modulate:a", 0.0, flash_duration)
		tween.tween_property(animated_sprite, "modulate:a", 1.0, flash_duration)
	tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body

func _on_detection_area_body_exited(body):
	if body == player:
		player = null

func attack():
	is_attacking = true
	attack_cooldown.start()
	var attack_anim = "attack"
	if abs(last_direction.x) > abs(last_direction.y):
		attack_anim = "attack"
		animated_sprite.flip_h = last_direction.x < 0
	else:
		attack_anim = "attack_down" if last_direction.y > 0 else "attack_up"
	animated_sprite.play(attack_anim)
	attack_animation_player.play("activate_hitbox")
	show_attack_indicator()

func show_attack_indicator():
	attack_indicator.visible = true
	var tween = create_tween()
	var flash_duration = 0.1
	tween.tween_property(attack_indicator, "modulate:a", 0.5, flash_duration)
	tween.tween_property(attack_indicator, "modulate:a", 1.0, flash_duration)
	tween.tween_property(attack_indicator, "modulate:a", 0.5, flash_duration)
	tween.tween_property(attack_indicator, "modulate:a", 1.0, flash_duration)

func _on_animated_sprite_2d_animation_finished():
	if animated_sprite.animation.begins_with("attack"):
		is_attacking = false
		hitbox_shape.disabled = true
		attack_animation_player.stop()
		attack_indicator.visible = false

func _on_hitbox_body_entered(body):
	if body.is_in_group("player"):
		var knockback_direction = (body.global_position - global_position).normalized()
		body.take_damage(1, knockback_direction)
		call_deferred("disable_hitbox_deferred")

func disable_hitbox_deferred():
	hitbox_shape.disabled = true

func enable_hitbox():
	hitbox_shape.disabled = false
