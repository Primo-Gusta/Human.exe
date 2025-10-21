extends CharacterBody2D

signal enemy_died

@export var speed = 75
var health = 3
var max_health = 3

var player = null
var is_dead = false
var is_in_knockback = false
var knockback_strength = 120.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var contact_damage_cooldown: Timer = $ContactDamageCooldown

# --- Variáveis de Divisão ---
@export var splits_into = 2
@export var small_worm_health_multiplier = 0.5
@export var small_worm_scale_multiplier = 0.5 # 50% do tamanho
@export var small_worm_speed_multiplier = 1.2
var is_small_worm = false # Flag para saber se este é um worm "filho"

# Variável para guardar a velocidade original antes do slow
var original_speed: float = -1.0
# Referência para o timer que controla a duração do slow
var slow_timer: Timer

func _ready():
	# Ajusta os status se for um worm pequeno
	if is_small_worm:
		health = int(max_health * small_worm_health_multiplier)
		max_health = health
		speed *= small_worm_speed_multiplier
		
		# Feedback visual para o clone (opcional)
		animated_sprite.modulate = Color(0.8, 0.8, 1.0) # Um tom levemente azulado/pálido
	slow_timer = Timer.new()
	slow_timer.one_shot = true
	slow_timer.timeout.connect(_on_slow_timer_timeout)
	add_child(slow_timer)


func _physics_process(delta):
	if is_dead: return

	# Se estiver em knockback (levando dano), a animação de dano tem prioridade
	if is_in_knockback:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 2 * delta)
		move_and_slide()
		return
	
	# Lógica de perseguição
	if player:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	update_animation()
	
	# Lógica de Dano por Contacto
	if contact_damage_cooldown.is_stopped():
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if is_instance_valid(collider) and collider.is_in_group("player"):
				var knockback_dir = (collider.global_position - global_position).normalized()
				collider.take_damage(1, knockback_dir, self)
				contact_damage_cooldown.start()
				break

func take_damage(amount: int, knockback_direction: Vector2 = Vector2.ZERO):
	if is_dead or is_in_knockback: return # Não toma dano se já estiver a ser atingido
		
	health -= amount
	is_in_knockback = true
	velocity = knockback_direction * knockback_strength
	
	# Toca a animação de dano
	animated_sprite.play("take_damage")
	
	if health <= 0:
		call_deferred("die")

func update_animation():
	# Animações de prioridade (morte, dano) impedem a mudança para idle/walk
	if is_dead or is_in_knockback: return

	var anim_name = "walk" if velocity.length() > 0.1 else "idle"
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)
	
	if velocity.x != 0:
		animated_sprite.flip_h = velocity.x < 0

func die():
	if is_dead: return
	is_dead = true
	collision_shape.disabled = true
	animated_sprite.play("dead")

	# Lógica de Divisão Simplificada
	if not is_small_worm:
		var WormScene = load("res://Scenes/Enemies/Worm.tscn")
		for i in range(splits_into):
			var new_worm = WormScene.instantiate()
			get_parent().add_child(new_worm)
			
			new_worm.is_small_worm = true
			new_worm.scale = self.scale * small_worm_scale_multiplier
			new_worm.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))

	enemy_died.emit()
	
	await get_tree().create_timer(0.5).timeout # Espera a animação de morte tocar um pouco
	if is_instance_valid(self):
		queue_free()

# --- Funções de Detecção e Sinais ---
func _on_detection_area_body_entered(body):
	if body.is_in_group("player"): player = body

func _on_detection_area_body_exited(body):
	if body == player: player = null

# Conectado ao sinal 'animation_finished' do AnimatedSprite2D
func _on_animated_sprite_2d_animation_finished():
	if animated_sprite.animation == "take_damage":
		is_in_knockback = false
		update_animation() # Volta para a animação de idle ou walk

# Esta é a função que a FirewallSkill irá chamar
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
