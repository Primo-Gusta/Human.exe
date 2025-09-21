# enemy.gd
extends CharacterBody2D

var speed = 75
var health = 3
var max_health = 3 # NOVO: Adicionado max_health para consistência
signal health_updated(current_health) # NOVO: Sinal para a HUD
signal enemy_died # NOVO: Sinal para o mundo saber quando um inimigo morre

var player = null # A detecção do player pode ser feita por uma Area2D local
var is_dead = false
var attack_range = 40.0
var is_attacking = false
var knockback_strength = 80.0
var is_in_knockback = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var detection_area = $DetectionArea # Renomeado para o nó Area2D pai
@onready var detection_area_shape = $DetectionArea/CollisionShape2D
@onready var hitbox_shape = $Hitbox/CollisionShape2D
@onready var attack_cooldown = $AttackCooldown
@onready var attack_animation_player = $AttackAnimationPlayer
@onready var attack_indicator = $AttackIndicator

var last_direction = Vector2.ZERO

func _ready():
	draw_attack_indicator_circle()
	health_updated.emit(health) # NOVO: Emite a vida inicial

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

	# Lógica da IA: Inimigo procura pelo player na detection_area
	if detection_area.get_overlapping_bodies().has(player): # Verifica se o player ainda está na área
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player > attack_range:
			var direction = (player.global_position - global_position).normalized()
			velocity = direction * speed
			last_direction = direction
		else:
			velocity = Vector2.ZERO
			if attack_cooldown.is_stopped():
				attack()
	else: # Se o player não estiver mais na área, pare.
		player = null # Garante que a referência é limpa
		velocity = Vector2.ZERO
	
	move_and_slide()
	update_animation()

func take_damage(amount, knockback_direction = Vector2.ZERO):
	if is_dead:
		return
	health -= amount
	health_updated.emit(health) # NOVO: Anuncia a nova vida
	
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

func die():
	if is_dead: # Proteção contra chamadas múltiplas
		return

	is_dead = true
	is_attacking = false
	is_in_knockback = false
	
	collision_shape.disabled = true
	detection_area_shape.disabled = true
	animated_sprite.play("dead")
	# player = null # REMOVIDO: O mundo que gerencia o player e o inimigo
	enemy_died.emit() # NOVO: Sinaliza ao mundo que o inimigo morreu
	
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
		player = body # Atribui o player à variável local do inimigo

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
	if body.is_in_group("player"): # Só ataca o player
		# A lógica de dano e knockback no player é do próprio player
		var knockback_direction = (body.global_position - global_position).normalized()
		body.take_damage(1, knockback_direction) # Player também recebe knockback
		call_deferred("disable_hitbox_deferred")

func disable_hitbox_deferred():
	hitbox_shape.disabled = true

func enable_hitbox():
	hitbox_shape.disabled = false
