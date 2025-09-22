# player.gd
extends CharacterBody2D

# --- SINAIS ---
signal health_updated(current_health)
signal player_died
signal player_took_damage
signal mana_updated(current_mana)
signal skill_q_cooldown_started(duration)
signal skill_e_cooldown_started(duration)
signal inventory_updated(inventory_data: Dictionary) # NOVO: Sinal para a UI do inventário
signal active_item_changed(item_data: ItemData) # NOVO: Avisa a HUD quando o item ativo muda
signal code_fragments_inventory_updated(fragments_inventory: Dictionary) # NOVO


# --- ATRIBUTOS ---
@export var velocidade = 150.0
var health = 10
var max_health = 10
var mana = 20
var max_mana = 20
@export var mana_regeneration_rate: float = 0.5 # NOVO: Mana por segundo

# --- INVENTÁRIOS ---
var inventory: Dictionary = {}
var code_fragments_inventory: Dictionary = {} # NOVO: Para componentes de upgrade

var unlocked_upgrade_ids: Array[String] = []

# --- HABILIDADES ---
@export var skill_q_mana_cost = 5
# ... (resto das variáveis de habilidade)
var skill_q_damage = 1
var skill_q_range = 60
var skill_q_cooldown_time = 2.0
var can_use_skill_q = true

@export var skill_e_mana_cost = 8
# ... (resto das variáveis de habilidade)
var skill_e_damage = 1
var skill_e_speed = 350
var skill_e_max_bounces = 2
var skill_e_cooldown_time = 3.0
var can_use_skill_e = true

# --- PRELOADS E REFERÊNCIAS ---
var RicochetProjectileScene = preload("res://scenes/projectiles/RicochetProjectile.tscn")
@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox_shape = $Hitbox/CollisionShape2D
@onready var skill_q_pulse_visual = $SkillQ_PulseVisual

# --- ESTADO ---
var is_attacking = false
var last_direction = Vector2(0, 1)
var active_item: ItemData = null # NOVO: Armazena o item que está "equipado" para uso
var hit_enemies = []
var is_dead = false
var is_in_knockback = false

func _ready():
	health_updated.emit(health)
	mana_updated.emit(mana)

# --- NOVO: Função de Inventário ---
func add_item_to_inventory(item_data: ItemData):
	# NOVO: Verifica se o inventário estava vazio ANTES de adicionar o novo item.
	var inventory_was_empty = inventory.is_empty()

	# Lógica existente para adicionar/empilhar o item
	if inventory.has(item_data):
		if item_data.is_stackable:
			inventory[item_data]["quantity"] += 1
		else:
			print("Item '", item_data.item_name, "' não é empilhável.")
			return
	else:
		inventory[item_data] = {"quantity": 1}
	
	print("Item adicionado: ", item_data.item_name, " | Quantidade: ", inventory[item_data]["quantity"])
	
	# NOVO: Se o inventário estava vazio, define o item recém-coletado como ativo.
	if inventory_was_empty:
		set_active_item(item_data)
	
	# Emite o sinal com todo o dicionário atualizado para a UI
	inventory_updated.emit(inventory, active_item)
	
func add_fragment_to_inventory(fragment_data: CodeFragmentData):
	# A CHAVE agora é o ID do fragmento (uma String), que é único e confiável.
	var id = fragment_data.fragment_id
	
	# Se o jogador já tem este tipo de fragmento, aumenta a quantidade.
	if code_fragments_inventory.has(id):
		code_fragments_inventory[id]["quantity"] += 1
	# Se for a primeira vez, cria uma nova entrada no inventário.
	else:
		code_fragments_inventory[id] = {
			"data": fragment_data, # Armazena a referência completa ao Resource.
			"quantity": 1
		}
	
	print("Fragmento de código coletado: '", fragment_data.fragment_text, "' | Quantidade: ", code_fragments_inventory[id]["quantity"])
	# Avisa a UI que este inventário específico foi atualizado.
	code_fragments_inventory_updated.emit(code_fragments_inventory)
	
func set_active_item(item_data: ItemData):
	# Se o item clicado for o mesmo que já está ativo, desativa-o (deixa as mãos livres)
	if active_item == item_data:
		active_item = null
	else:
		active_item = item_data
	
	# Avisa a HUD e qualquer outro sistema sobre a mudança
	active_item_changed.emit(active_item)
	
	if active_item:
		print("Item ativo definido como: ", active_item.item_name)
	else:
		print("Nenhum item ativo.")

func _physics_process(delta):
	if is_dead:
		return
	
	if is_in_knockback:
		velocity = velocity.move_toward(Vector2.ZERO, velocidade * 2 * delta)
		move_and_slide()
		return

	if is_attacking:
		velocity = velocity.move_toward(Vector2.ZERO, velocidade * delta)
		move_and_slide()
		return

	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		velocity = direction.normalized() * velocidade
		last_direction = direction
	else:
		velocity = Vector2.ZERO
	
	update_animation(direction)

	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		hit_enemies.clear()
		hitbox_shape.disabled = false
		var attack_anim = "attack"
		if abs(last_direction.x) > abs(last_direction.y):
			attack_anim = "attack"
			animated_sprite.flip_h = last_direction.x < 0
		else:
			attack_anim = "attack_down" if last_direction.y > 0 else "attack_up"
		
		animated_sprite.play(attack_anim)
	
	if Input.is_action_just_pressed("skill_q"):
		use_skill_q()
	
	if Input.is_action_just_pressed("skill_e"):
		use_skill_e()
		
	if Input.is_action_just_pressed("use_item"):
		use_active_item()
		
	# --- NOVO: Lógica de Regeneração de Mana ---
	# Adicione este bloco no início da função
	if mana < max_mana:
		mana += mana_regeneration_rate * delta
		mana = min(mana, max_mana) # Garante que a regeneração não ultrapasse o máximo
		mana_updated.emit(mana)
	# --- FIM do novo bloco ---

	move_and_slide()

# --- Funções de Gerenciamento de Mana (NOVAS) ---
func use_mana(amount: int):
	mana -= amount
	mana = max(0, mana)
	mana_updated.emit(mana)
	print("Mana gasta. Mana atual: ", mana)

func restore_mana(amount: int):
	mana += amount
	mana = min(mana, max_mana)
	mana_updated.emit(mana)
	print("Mana restaurada. Mana atual: ", mana)

# --- Funções de Habilidade (ATUALIZADAS) ---
func use_skill_q():
	if not can_use_skill_q or is_dead or mana < skill_q_mana_cost:
		if mana < skill_q_mana_cost:
			print("Mana insuficiente para a Habilidade Q!")
		return

	can_use_skill_q = false
	use_mana(skill_q_mana_cost)
	skill_q_cooldown_started.emit(skill_q_cooldown_time)

	print("Função: Executar() ativada!")

	var enemies_in_range = []
	var all_enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in all_enemies:
		if global_position.distance_to(enemy.global_position) <= skill_q_range:
			enemies_in_range.append(enemy)

	for enemy in enemies_in_range:
		var knockback_direction = (enemy.global_position - global_position).normalized()
		enemy.take_damage(skill_q_damage, knockback_direction)

	get_tree().create_timer(skill_q_cooldown_time).timeout.connect(on_skill_q_cooldown_finished)
	play_skill_q_visual()

func use_skill_e():
	if not can_use_skill_e or is_dead or mana < skill_e_mana_cost:
		if mana < skill_e_mana_cost:
			print("Mana insuficiente para a Habilidade E!")
		return

	can_use_skill_e = false
	use_mana(skill_e_mana_cost)
	skill_e_cooldown_started.emit(skill_e_cooldown_time)

	print("Habilidade 'Loop de Dano' (Ricochete) ativada!")

	var projectile_instance = RicochetProjectileScene.instantiate()
	get_parent().add_child(projectile_instance)
	projectile_instance.global_position = global_position
	projectile_instance.setup_projectile(last_direction, skill_e_damage, skill_e_max_bounces)

	get_tree().create_timer(skill_e_cooldown_time).timeout.connect(on_skill_e_cooldown_finished)

# --- Demais funções ---
# ... (todas as outras funções como `update_animation`, `take_damage`, `die`, etc., permanecem as mesmas)
# ... (as colei aqui para garantir que nada mais seja perdido)

func on_skill_q_cooldown_finished():
	can_use_skill_q = true
	
func on_skill_e_cooldown_finished():
	can_use_skill_e = true

func update_animation(direction):
	if is_attacking or is_in_knockback:
		return
		
	var anim_name = "idle"
	var anim_direction = direction if direction != Vector2.ZERO else last_direction
	
	if direction != Vector2.ZERO:
		if abs(anim_direction.x) > abs(anim_direction.y):
			anim_name = "walk"
			animated_sprite.flip_h = anim_direction.x < 0
		else:
			anim_name = "walk_down" if anim_direction.y > 0 else "walk_up"
	else:
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
		update_animation(Vector2.ZERO)

func _on_hitbox_body_entered(body):
	if body.is_in_group("enemies") and not body in hit_enemies:
		hit_enemies.append(body)
		var knockback_direction = (body.global_position - global_position).normalized()
		body.take_damage(1, knockback_direction)
		
func take_damage(amount, knockback_direction = Vector2.ZERO):
	if is_dead:
		return
	health -= amount
	health_updated.emit(health)
	player_took_damage.emit()
	is_in_knockback = true
	velocity = knockback_direction * 80.0
	get_tree().create_timer(0.2).timeout.connect(on_knockback_finished)
	
	if health <= 0 and not is_dead:
		call_deferred("die")

func on_knockback_finished():
	is_in_knockback = false
		
func die():
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	is_in_knockback = false
	velocity = Vector2.ZERO
	animated_sprite.play("dead")
	player_died.emit()
	
	var tween = create_tween()
	var num_flashes = 7
	for i in range(num_flashes):
		var flash_duration = 0.2 * (1.0 - float(i) / num_flashes)
		tween.tween_property(animated_sprite, "modulate:a", 0.0, flash_duration)
		tween.tween_property(animated_sprite, "modulate:a", 1.0, flash_duration)
	tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
	
func play_skill_q_visual():
	if not is_instance_valid(skill_q_pulse_visual):
		return
	skill_q_pulse_visual.modulate = Color(0, 1, 1, 0.7)
	skill_q_pulse_visual.scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(skill_q_pulse_visual, "scale", Vector2(skill_q_range / 30.0, skill_q_range / 30.0), 0.2)
	tween.tween_property(skill_q_pulse_visual, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): skill_q_pulse_visual.scale = Vector2(0.1, 0.1))
	
# --- Funções de Gerenciamento de Vida (NOVA) ---
# Adicione esta função para centralizar a cura
func restore_health(amount: int):
	health += amount
	health = min(health, max_health) # Garante que a vida não ultrapasse o máximo
	health_updated.emit(health)
	print("Vida restaurada. Vida atual: ", health)
# --- NOVAS Funções de Gerenciamento de Itens ---
# Adicione estas duas novas funções ao final do seu script
func use_active_item():
	if is_dead or not active_item:
		return

	print("Tentando usar o item: ", active_item.item_name)
	
	# Usa um 'match' para decidir o que fazer com base no efeito do item
	match active_item.effect_type:
		"Cura":
			# NOVO: Verifica se a vida já está cheia
			if health >= max_health:
				print("Vida já está cheia! Não é possível usar a poção.")
				return # Interrompe a função aqui, o item não é consumido
			
			restore_health(active_item.effect_value)

		"Mana": # Nota: Certifique-se que no seu .tres o Effect Type está como "RestauraMana"
			# NOVO: Verifica se a mana já está cheia
			if mana >= max_mana:
				print("Mana já está cheia! Não é possível usar a poção.")
				return # Interrompe a função aqui, o item não é consumido
			
			restore_mana(active_item.effect_value)
			
		_: 
			print("O item '", active_item.item_name, "' não tem efeito.")
			return

	# A função só chega aqui se o item foi usado com sucesso
	remove_item_from_inventory(active_item)

func remove_item_from_inventory(item_data: ItemData):
	if not inventory.has(item_data):
		return # Checagem de segurança

	# Diminui a quantidade
	inventory[item_data]["quantity"] -= 1

	# Se a quantidade chegar a zero, remove o item do inventário
	if inventory[item_data]["quantity"] <= 0:
		inventory.erase(item_data)
		# Se o item que acabou era o item ativo, limpa a "mão" do jogador
		set_active_item(null)
	
	# Notifica a UI sobre a mudança no inventário
	inventory_updated.emit(inventory, active_item)
	
func apply_skill_upgrade(upgrade_effect_id: String):
	# Impede que o mesmo upgrade seja aplicado duas vezes
	if upgrade_effect_id in unlocked_upgrade_ids:
		print("Upgrade '", upgrade_effect_id, "' já está aplicado.")
		return

	print("Aplicando upgrade: ", upgrade_effect_id)
	
	# O "cérebro" do sistema de upgrades.
	# Ele verifica o ID do upgrade e aplica a mudança correspondente.
	match upgrade_effect_id:
		"pulse_damage_1":
			skill_q_damage += 1
			print("Dano do Pulso aumentado para: ", skill_q_damage)
		"loop_bounces_1":
			skill_e_max_bounces += 1
			print("Ricochetes do Loop aumentado para: ", skill_e_max_bounces)
		# Adicionaremos mais 'cases' aqui para cada novo upgrade que criarmos
		_:
			print("AVISO: Tentativa de aplicar um upgrade com ID desconhecido: '", upgrade_effect_id, "'")
			return # Não adiciona um ID desconhecido à lista de desbloqueados

	# Marca o upgrade como desbloqueado e permanente
	unlocked_upgrade_ids.append(upgrade_effect_id)
