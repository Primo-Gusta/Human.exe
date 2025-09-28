extends Area2D

var direction: Vector2 = Vector2.ZERO
var speed: float = 300.0
var damage: int = 5

func _ready():
	body_entered.connect(_on_body_entered)
	# O projétil se autodestrói depois de 5 segundos para não poluir a cena
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta):
	# Move o projétil na direção definida
	global_position += direction * speed * delta

func _on_body_entered(body):
	# Se atingir o jogador, causa dano e se destrói
	if body.is_in_group("player"):
		var knockback_direction = global_position.direction_to(body.global_position)
		body.take_damage(damage, knockback_direction)
		queue_free()
	# Opcional: se atingir uma parede, também se destrói
	# elif body.is_in_group("walls"):
	#	  queue_free()
