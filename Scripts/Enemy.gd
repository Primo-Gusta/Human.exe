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

# Variável para guardar a velocidade original antes do slow
var original_speed: float = -1.0
# Referência para o timer que controla a duração do slow
var slow_timer: Timer

var last_direction = Vector2.ZERO

func _ready():
	health_updated.emit(health) # NOVO: Emite a vida inicial
	slow_timer = Timer.new()
	slow_timer.one_shot = true
	slow_timer.timeout.connect(_on_slow_timer_timeout)
	add_child(slow_timer)

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
		var direction_to_player = (player.global_position - global_position).normalized()
		var distance_to_player = global_position.distance_to(player.global_position)
		
		if distance_to_player > attack_range:
			# Lógica de perseguição normal
			velocity = direction_to_player * speed
			last_direction = direction_to_player
		else:
			# Está no alcance de ataque, pára de se mover
			velocity = Vector2.ZERO
			
			# --- NOVA CONDIÇÃO DE ATAQUE ---
			# Verifica se a componente horizontal da direção é a dominante
			if abs(direction_to_player.x) > abs(direction_to_player.y):
				# Se sim, E se o cooldown terminou, ataca
				if attack_cooldown.is_stopped():
					attack()
			# Se não (está acima/abaixo), o inimigo não faz nada, esperando
			# que o jogador se mova para uma posição atacável.
	else:
		player = null
		velocity = Vector2.ZERO
	
	move_and_slide()
	update_animation()

func take_damage(amount, knockback_direction = Vector2.ZERO):
	if is_dead or is_in_knockback: return # Não pode tomar dano se já estiver em knockback
	
	health -= amount
	health_updated.emit(health)
	
	is_in_knockback = true
	velocity = knockback_direction * knockback_strength
	
	# --- ADIÇÃO AQUI ---
	# Toca a animação de levar dano
	animated_sprite.play("take_damage")
	
	# O timer existente para o knockback já controla a duração do estado
	get_tree().create_timer(0.2).timeout.connect(on_knockback_finished)
	
	if health <= 0:
		call_deferred("die")


func on_knockback_finished():
	is_in_knockback = false

func update_animation():
	if is_attacking or is_in_knockback:
		return

	# Se o inimigo tem velocidade, toca a animação "walk"
	if velocity.length() > 0.1:
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")
	# Se estiver parado, toca a animação "idle"
	else:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")

	# Vira o sprite com base na direcção do movimento horizontal
	# (só vira se houver movimento no eixo X)
	if abs(velocity.x) > 0.01:
		animated_sprite.flip_h = velocity.x < 0

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
	
	# Vira para o jogador antes de atacar
	if player.global_position.x < global_position.x:
		animated_sprite.flip_h = true
	else:
		animated_sprite.flip_h = false

	# Toca sempre a mesma animação de ataque horizontal
	animated_sprite.play("attack")
	attack_animation_player.play("activate_hitbox")

func _on_animated_sprite_2d_animation_finished():
	if animated_sprite.animation.begins_with("attack"):
		is_attacking = false
		hitbox_shape.disabled = true
		attack_animation_player.stop()
		# Ao fim do ataque, volta para a animação normal
		update_animation()
	
	# Se a animação de levar dano terminar, também volta para a animação normal
	# Isto garante que ele não fica preso na pose de "hit"
	elif animated_sprite.animation == "take_damage":
		update_animation()

func _on_hitbox_body_entered(body):
	if body.is_in_group("player"): # Só ataca o player
		# A lógica de dano e knockback no player é do próprio player
		var knockback_direction = (body.global_position - global_position).normalized()
		body.take_damage(1, knockback_direction, self) # Player também recebe knockback
		call_deferred("disable_hitbox_deferred")

func disable_hitbox_deferred():
	hitbox_shape.disabled = true

func enable_hitbox():
	hitbox_shape.disabled = false
	
func apply_slow(duration: float):
	# Se o inimigo já não estiver lento, guarda a sua velocidade original
	if original_speed == -1.0:
		original_speed = speed

	# Reduz a velocidade actual (ex: para 50%)
	speed = original_speed * 0.5
	
	# Inicia ou reinicia o timer com a nova duração
	slow_timer.start(duration)
	
	# Efeito visual (opcional): muda a cor para indicar o slow
	animated_sprite.modulate = Color.CORNFLOWER_BLUE

# Chamado quando o timer do slow termina
func _on_slow_timer_timeout():
	# Restaura a velocidade original
	if original_speed != -1.0:
		speed = original_speed
		original_speed = -1.0 # Reseta a variável
	
	# Restaura a cor original
	animated_sprite.modulate = Color.WHITE
