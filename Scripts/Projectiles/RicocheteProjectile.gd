extends Area2D

@export var speed = 300
var damage = 1
var max_bounces = 2
var current_bounces = 0
var direction = Vector2.ZERO
var hit_enemies = []

# --- FLAGS DE UPGRADE ---
var smart_loop_enabled: bool = false
var fragmentation_enabled: bool = false

# --- CONSTANTES DO FRAGMENTO ---
const FRAGMENT_DAMAGE = 1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	body_entered.connect(on_body_entered)
	animated_sprite.play("fly")

func _physics_process(delta):
	position += direction * speed * delta
	rotation = direction.angle()

# Função principal de configuração, chamada pela habilidade
func setup_projectile(dir: Vector2, dmg: int, initial_bounces: int, p_smart_loop: bool, p_fragmentation: bool):
	self.direction = dir.normalized()
	self.damage = dmg
	self.max_bounces = initial_bounces
	self.smart_loop_enabled = p_smart_loop
	self.fragmentation_enabled = p_fragmentation
	rotation = direction.angle()

# Função para transformar uma instância num "fragmento"
func setup_as_fragment():
	# Define a escala para 50% do tamanho original
	self.scale = Vector2(0.5, 0.5) 
	
	# Fragmentos não ricocheteiam e causam dano fixo
	self.max_bounces = 0
	self.damage = FRAGMENT_DAMAGE
	
	# Garante que um fragmento não cria mais fragmentos
	self.fragmentation_enabled = false 
	
	# Lógica para o atraso de 1 segundo
	set_physics_process(false) # Para o projétil
	var timer = get_tree().create_timer(1.0)
	await timer.timeout
	
	# Após 1 segundo, activa o movimento numa direcção aleatória
	if is_instance_valid(self):
		self.direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
		set_physics_process(true)
		
		# Autodestrói-se após 2 segundos de movimento
		get_tree().create_timer(2.0).timeout.connect(queue_free)

# Função de colisão, agora assíncrona para a fragmentação
func on_body_entered(body) -> void:
	if body.is_in_group("enemies") and not hit_enemies.has(body):
		hit_enemies.append(body)
		
		var knockback_direction = (global_position - body.global_position).normalized()
		body.take_damage(damage, knockback_direction)
		
		# LÓGICA DE FRAGMENTAÇÃO
		if fragmentation_enabled:
			var fragment = self.duplicate() # Cria uma cópia de si mesmo
			get_parent().add_child(fragment)
			fragment.global_position = global_position
			fragment.setup_as_fragment() # Configura a cópia como um fragmento
			
		# LÓGICA DE RICOCHETE
		if current_bounces < max_bounces:
			current_bounces += 1
			var next_target = find_next_target()
			if next_target:
				direction = (next_target.global_position - global_position).normalized()
				animated_sprite.play("fly")
				return # Sai da função para continuar o seu percurso
		
		# Se não ricocheteou, autodestrói-se
		queue_free()
		
	elif not body.is_in_group("player") and not body.is_in_group("enemies"):
		# Se atingir uma parede, também se autodestrói
		queue_free()

# Função de procura de alvos, com a lógica do "Loop Inteligente"
func find_next_target():
	var closest_enemy = null
	var min_distance = INF

	var all_enemies = get_tree().get_nodes_in_group("enemies")
	var available_targets = []
	
	# 1. Primeiro, tenta encontrar alvos que ainda não foram atingidos
	for enemy in all_enemies:
		if not hit_enemies.has(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead):
			available_targets.append(enemy)
			
	# 2. LÓGICA DO LOOP INTELIGENTE: Se não encontrou alvos novos E o upgrade está activo...
	if available_targets.is_empty() and smart_loop_enabled:
		print("Loop Inteligente: A procurar por alvos repetidos.")
		# ...procura em todos os inimigos, excepto o último que foi atingido
		var last_hit = hit_enemies.back()
		for enemy in all_enemies:
			if enemy != last_hit and not (enemy.has_method("is_dead") and enemy.is_dead):
				available_targets.append(enemy)

	# 3. Procura o alvo mais próximo da lista de candidatos disponíveis
	for enemy in available_targets:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_enemy = enemy

	return closest_enemy
