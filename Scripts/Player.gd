# player.gd
extends CharacterBody2D

@export var velocidade = 150.0
var health = 10
var max_health = 10 # NOVO: Consistência com o inimigo
signal health_updated(current_health) # NOVO: Sinal para a HUD
signal player_died # NOVO: Sinal para o mundo quando o jogador morre
signal player_took_damage # NOVO: Sinal para o mundo quando o player leva dano

#Q Skill variáveis
var skill_q_damage = 1 # Dano base da habilidade
var skill_q_range = 60 # Raio de alcance da habilidade
var skill_q_cooldown_time = 2.0 # Tempo de recarga em segundos
var can_use_skill_q = true # Flag para controlar se a habilidade pode ser usada
# NOVO: Sinal para a HUD saber o estado do cooldown
signal skill_q_cooldown_started(duration) 

#E Skill variáveis
var skill_e_damage = 1
var skill_e_speed = 350 # Velocidade do projétil de ricochete
var skill_e_max_bounces = 2 # Quantos ricochetes o projétil pode fazer
var skill_e_cooldown_time = 3.0 # Cooldown da habilidade 'E'
var can_use_skill_e = true # Flag para controlar o uso
# NOVO: Sinal para a HUD saber o estado do cooldown do 'E'
signal skill_e_cooldown_started(duration)

# NOVO: Variável para carregar a cena do projétil
var RicochetProjectileScene = preload("res://scenes/projectiles/RicochetProjectile.tscn") # Ajuste o caminho conforme onde você salvou

var is_attacking = false
var last_direction = Vector2(0, 1)
var hit_enemies = []
var is_dead = false
var is_in_knockback = false # NOVO: Para o player também ter knockback

@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox_shape = $Hitbox/CollisionShape2D
# @onready var camera = $Camera2D # REMOVIDO: Câmera deve ser gerenciada pelo mundo ou um nó dedicado

func _ready():
	health_updated.emit(health) # NOVO: Emite a vida inicial
	# Certifique-se de que o grupo "player" está definido no nó do Player na cena

func _physics_process(delta):
	# Prioridade 1: Morte. Se estiver morto, nada mais importa.
	if is_dead:
		return
	
	# Prioridade 2: Knockback. Se estiver em knockback, só lida com isso.
	if is_in_knockback:
		velocity = velocity.move_toward(Vector2.ZERO, velocidade * 2 * delta)
		move_and_slide()
		# Não atualiza a animação aqui se você quiser uma pose de "hit" estática
		return

	# Prioridade 3: Ataque. Se estiver atacando, não permite movimento do jogador.
	if is_attacking:
		velocity = velocity.move_toward(Vector2.ZERO, velocidade * delta) # Desacelera durante o ataque
		move_and_slide()
		# Não atualiza a animação aqui, pois a animação de ataque está tocando
		return

	# Lógica Normal do Jogador (se nenhuma das anteriores for verdade)
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		velocity = direction.normalized() * velocidade
		last_direction = direction
	else:
		velocity = Vector2.ZERO
	
	update_animation(direction)

	if Input.is_action_just_pressed("attack") and not is_attacking: # Impede spam de ataque
		is_attacking = true
		hit_enemies.clear() # Limpa a lista de inimigos atingidos para este ataque
		hitbox_shape.disabled = false
		var attack_anim = "attack"
		if abs(last_direction.x) > abs(last_direction.y):
			attack_anim = "attack"
			animated_sprite.flip_h = last_direction.x < 0
		else:
			attack_anim = "attack_down" if last_direction.y > 0 else "attack_up"
		
		animated_sprite.play(attack_anim)
# NOVO: Ativa a habilidade 'Q'
	if Input.is_action_just_pressed("skill_q"): # Você precisará adicionar esta Input Action
		use_skill_q()
	
# NOVO: Ativa a habilidade 'E'
	if Input.is_action_just_pressed("skill_e"): # Você precisará adicionar esta Input Action
		use_skill_e()


	move_and_slide()

func update_animation(direction):
	if is_attacking or is_in_knockback: # Se estiver atacando ou em knockback, a animação é controlada por outro lugar
		return
		
	var anim_name = "idle"
	var anim_direction = direction if direction != Vector2.ZERO else last_direction # Usa a direção atual ou a última para idle
	
	if direction != Vector2.ZERO: # Se estiver se movendo
		if abs(anim_direction.x) > abs(anim_direction.y):
			anim_name = "walk"
			animated_sprite.flip_h = anim_direction.x < 0
		else:
			anim_name = "walk_down" if anim_direction.y > 0 else "walk_up"
	else: # Se estiver parado
		if abs(last_direction.x) > abs(last_direction.y):
			anim_name = "idle"
			animated_sprite.flip_h = last_direction.x < 0
		else:
			anim_name = "idle_down" if last_direction.y > 0 else "idle_up"
	
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func _on_animated_sprite_2d_animation_finished():
	if animated_sprite.animation.begins_with("attack"):
		is_attacking = false
		hitbox_shape.disabled = true
		# Opcional: Se quiser uma animação de "idle" após o ataque, chame update_animation aqui.
		update_animation(Vector2.ZERO) # Chame com zero para voltar para o idle

func _on_hitbox_body_entered(body):
	if body.is_in_group("enemies") and not body in hit_enemies:
		hit_enemies.append(body)
		
		# 1. Calcula a direção do knockback para o inimigo (do jogador PARA o inimigo)
		var knockback_direction = (body.global_position - global_position).normalized()
		
		# 2. Envia o dano E a direção do knockback para o inimigo
		body.take_damage(1, knockback_direction) # Inimigo também recebe knockback
		
		# 3. Aplica o recoil no jogador (na direção OPOSTA)
		# velocity = -knockback_direction * 60.0 # Este é o recoil do jogador, você pode ajustar
		# É importante que o recoil não seja muito forte para não atrapalhar o ataque do jogador
		# Talvez apenas um pequeno empurrão, ou deixar o ataque travar o jogador um pouco
		
func take_damage(amount, knockback_direction = Vector2.ZERO): # NOVO: Recebe direção do knockback
	if is_dead:
		return
	health -= amount
	health_updated.emit(health) # NOVO: Anuncia a nova vida
	player_took_damage.emit() # NOVO: Emite o sinal de dano
	# NOVO: Aplica knockback no player
	is_in_knockback = true
	velocity = knockback_direction * 80.0 # Força do knockback no player
	get_tree().create_timer(0.2).timeout.connect(on_knockback_finished)
	
	# Print pode ser útil para debug, mas será removido depois
	print("Davi ATINGIDO! Vida restante: ", health)

	if health <= 0 and not is_dead:
		call_deferred("die")

func on_knockback_finished(): # NOVO: Função para o player sair do estado de knockback
	is_in_knockback = false
		
func die():
	if is_dead: # Proteção contra chamadas múltiplas
		return

	is_dead = true
	is_attacking = false
	is_in_knockback = false # Garante que não está em knockback ao morrer
	velocity = Vector2.ZERO # Impede qualquer movimento residual
	animated_sprite.play("dead")
	
	player_died.emit() # NOVO: Avisa ao mundo que o jogador morreu
	
	# REMOVIDO: Toda a lógica de CanvasModulate, camera zoom e reload_current_scene.
	# Isso será de responsabilidade do World.gd.

	# Opcional: Efeitos de fade-out do sprite do jogador ao morrer,
	# se o World não for fazer um fade-out global da tela.
	var tween = create_tween()
	var num_flashes = 7
	for i in range(num_flashes):
		var flash_duration = 0.2 * (1.0 - float(i) / num_flashes)
		tween.tween_property(animated_sprite, "modulate:a", 0.0, flash_duration)
		tween.tween_property(animated_sprite, "modulate:a", 1.0, flash_duration)
	tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
	
func use_skill_q():
	if not can_use_skill_q or is_dead: # Não pode usar se estiver em cooldown ou morto
		return

	can_use_skill_q = false # Coloca a habilidade em cooldown
	skill_q_cooldown_started.emit(skill_q_cooldown_time) # Avisa a HUD

	print("Função: Executar() ativada!")

	# --- Lógica para detectar inimigos e causar dano ---
	# Podemos usar um Area2D temporário ou percorrer todos os inimigos existentes

	# Opção mais simples para agora: percorrer todos os inimigos do mundo
	var enemies_in_range = []
	var all_enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in all_enemies:
		if global_position.distance_to(enemy.global_position) <= skill_q_range:
			enemies_in_range.append(enemy)

	for enemy in enemies_in_range:
		# Calcula a direção do knockback para o inimigo
		var knockback_direction = (enemy.global_position - global_position).normalized()
		enemy.take_damage(skill_q_damage, knockback_direction)
		print("Inimigo ", enemy.name, " atingido pela Função: Executar()!")

	# Inicia o cooldown
	get_tree().create_timer(skill_q_cooldown_time).timeout.connect(on_skill_q_cooldown_finished)

	# Chama a função para o feedback visual (Pulso)
	play_skill_q_visual()
	
func on_skill_q_cooldown_finished():
	can_use_skill_q = true
	print("Função: Executar() - Cooldown encerrado!")
	
# player.gd (adicionar esta referência no topo)
@onready var skill_q_pulse_visual = $SkillQ_PulseVisual # NOVO: Para o visual do pulso

# player.gd (adicione esta função, ex: abaixo de on_skill_q_cooldown_finished)
func play_skill_q_visual():
	if not is_instance_valid(skill_q_pulse_visual):
		return

	skill_q_pulse_visual.modulate = Color(0, 1, 1, 0.7) # Começa ciano e semi-transparente
	skill_q_pulse_visual.scale = Vector2(0.1, 0.1) # Começa pequeno

	var tween = create_tween()
	tween.set_parallel(true) # Anima escala e transparência juntas

	# Aumenta a escala do círculo até o raio da habilidade
	tween.tween_property(skill_q_pulse_visual, "scale", Vector2(skill_q_range / 30.0, skill_q_range / 30.0), 0.2)
	# Faz o círculo desaparecer
	tween.tween_property(skill_q_pulse_visual, "modulate:a", 0.0, 0.2)

	tween.tween_callback(func(): skill_q_pulse_visual.scale = Vector2(0.1, 0.1)) # Reseta a escala após a animação

func use_skill_e():
	if not can_use_skill_e or is_dead:
		return

	can_use_skill_e = false
	skill_e_cooldown_started.emit(skill_e_cooldown_time) # Avisa a HUD

	print("Habilidade 'Loop de Dano' (Ricochete) ativada!")

	# --- Lógica para instanciar e configurar o projétil ---
	var projectile_instance = RicochetProjectileScene.instantiate()
	get_parent().add_child(projectile_instance) # Adiciona o projétil à cena do mundo

	# Define a posição inicial do projétil (na posição do jogador)
	projectile_instance.global_position = global_position
	
	# Configura o projétil com os parâmetros da habilidade
	projectile_instance.setup_projectile(last_direction, skill_e_damage, skill_e_max_bounces)

	# Inicia o cooldown
	get_tree().create_timer(skill_e_cooldown_time).timeout.connect(on_skill_e_cooldown_finished)
	
func on_skill_e_cooldown_finished():
	can_use_skill_e = true
	print("Loop de Dano (Ricochete) - Cooldown encerrado!")
