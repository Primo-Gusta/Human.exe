extends Area2D

@export var damage = 1
@export var speed = 300
@export var max_bounces = 2 # Quantas vezes o projétil pode ricochetear
var current_bounces = 0
var direction = Vector2.ZERO # Direção atual do projétil
var hit_enemies = [] # Lista de inimigos que já foram atingidos NESTE projétil

func _ready():
	# Conecta o sinal body_entered para detectar colisões
	body_entered.connect(on_body_entered)

func _physics_process(delta):
	position += direction * speed * delta

func setup_projectile(dir: Vector2, dmg: int, initial_bounces: int):
	direction = dir.normalized()
	damage = dmg
	max_bounces = initial_bounces

func on_body_entered(body):
	# Verifica se o corpo é um inimigo e se ainda não foi atingido por ESTE projétil
	if body.is_in_group("enemies") and not hit_enemies.has(body):
		hit_enemies.append(body) # Adiciona à lista de atingidos

		# Causa dano ao inimigo
		var knockback_direction = (body.global_position - global_position).normalized()
		body.take_damage(damage, knockback_direction)
		print("RicochetProjectile atingiu: ", body.name)

		# Lógica de Ricochete
		if current_bounces < max_bounces:
			current_bounces += 1
			var next_target = find_next_target()
			if next_target:
				# Ajusta a direção para o novo alvo
				direction = (next_target.global_position - global_position).normalized()
				# Opcional: Efeito visual/sonoro de ricochete
				return # Não se autodestrói ainda
			else:
				print("Ricochet: Não encontrou mais alvos.")
		else:
			print("Ricochet: Limite de ricochetes atingido.")

		# Se não ricocheteou, autodestrói-se
		queue_free()
	elif not body.is_in_group("player") and not body.is_in_group("enemies"):
		# Se atingir algo que não é player nem inimigo (ex: parede), se autodestrói.
		print("Ricochet: Atingiu uma parede ou objeto não-inimigo.")
		queue_free()

func find_next_target():
	var closest_enemy = null
	var min_distance = INF # Infinito para a primeira comparação

	# Procura por todos os inimigos no mundo
	var all_enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in all_enemies:
		# Ignora inimigos que já foram atingidos por este projétil ou que estão mortos
		if hit_enemies.has(enemy) or (enemy.has_method("is_dead") and enemy.is_dead):
			continue

		var distance = global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_enemy = enemy

	# Opcional: Definir um raio máximo para buscar o próximo alvo
	# if closest_enemy and min_distance > 200: # Exemplo: 200 pixels de raio
	#    return null

	return closest_enemy
