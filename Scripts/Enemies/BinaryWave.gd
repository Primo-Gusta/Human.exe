extends Area2D

signal wave_finished

var speed: float
var travel_distance: float

@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	body_entered.connect(_on_body_entered)

func setup_wave(width: float, height: float, travel_time: float):
	travel_distance = width
	speed = travel_distance / travel_time

	# 1. Configura a área de dano (CollisionShape2D)
	collision_shape.disabled = false # <-- A CORREÇÃO ESTÁ AQUI
	collision_shape.shape.size = Vector2(width, height)
	collision_shape.position = Vector2(width / 2.0, height / 2.0)

	# 2. Configura o emissor de partículas (GPUParticles2D)
	# O 'emission_box_extents' é metade do tamanho total
	particles.process_material.set("emission_box_extents", Vector3(width / 2.0, height / 2.0, 1))
	particles.position = Vector2(width / 2.0, height / 2.0)
	particles.amount = int(width * height / 100) # Ajusta a quantidade de partículas ao tamanho

func _physics_process(delta):
	position.x += speed * delta # Move o conjunto todo para a direita
	
	# Destrói quando o nó sair da tela
	if position.x > travel_distance:
		wave_finished.emit()
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("player"):
		var knockback_direction = global_position.direction_to(body.global_position)
		body.take_damage(15, knockback_direction)
		# Não desativamos a colisão, para que a onda seja uma barreira contínua
