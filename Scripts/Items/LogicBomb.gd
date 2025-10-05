extends Node2D

@export var damage = 5
@export var explosion_radius = 100.0
@export var detonation_time = 2.0 # Tempo antes de começar a explosão

@onready var timer = $Timer
@onready var explosion_area = $ExplosionArea
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	# Configura o tamanho da área de explosão
	explosion_area.get_node("CollisionShape2D").shape.radius = explosion_radius
	
	# Conecta os sinais
	timer.timeout.connect(_on_timer_timeout)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Inicia a animação de "arming" e a contagem decrescente
	animated_sprite.play("arming")
	timer.wait_time = detonation_time
	timer.start()

# Chamado quando o tempo de espera (2s) termina
func _on_timer_timeout():
	# Impede que a bomba possa ser movida ou interagida
	# Toca a animação de explosão
	animated_sprite.play("explode")

# Chamado QUANDO a animação "explode" TERMINA
func _on_animation_finished():
	# Garante que só reagimos ao fim da animação de explosão
	if animated_sprite.animation == "explode":
		print("BOMBA LÓGICA: Detonando!")
		
		# Causa dano aos inimigos na área
		var bodies = explosion_area.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("enemies"):
				var knockback_dir = (body.global_position - global_position).normalized()
				body.take_damage(damage, knockback_dir)
		
		# --- VFX (Efeito Visual) ---
		# Como você pediu, o código para o VFX está aqui, comentado.
		# var vfx_instance = preload("res://Scenes/VFX/ExplosionVFX.tscn").instantiate()
		# get_parent().add_child(vfx_instance)
		# vfx_instance.global_position = global_position
		
		# Destrói a bomba
		queue_free()
