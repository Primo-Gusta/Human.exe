extends CharacterBody2D

# --- SINAIS ---
signal health_updated(current_health)
signal player_died
signal player_took_damage
signal mana_updated(current_mana)
signal inventory_updated(inventory: Dictionary, current_active_item: ItemData)
signal active_item_changed(item_data: ItemData)
signal code_fragments_inventory_updated(fragments_inventory: Dictionary)
signal equipped_skills_changed(equipped_q: Skill, equipped_e: Skill)
signal skill_used(slot: String, duration: float)
signal player_ready(player_node)

# --- ATRIBUTOS ---
@export var velocidade = 150.0
var health = 5
var max_health = 5
var mana = 20
var max_mana = 20
@export var mana_regeneration_rate: float = 0.5

# --- INVENTÁRIOS ---
var inventory: Dictionary = {}
var current_active_item: ItemData = null
var code_fragments_inventory: Dictionary = {}
var unlocked_upgrade_ids: Array[String] = []

# --- HABILIDADES EQUIPADAS ---
var equipped_skill_q: Skill = null # Armazena a INSTÂNCIA da cena da skill
var equipped_skill_e: Skill = null # Armazena a INSTÂNCIA da cena da skill
@export var default_skill_q: SkillData
@export var default_skill_e: SkillData

# --- PRELOADS E REFERÊNCIAS ---
@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox_shape = $Hitbox/CollisionShape2D
@onready var equipped_skills_container = $EquippedSkillsContainer
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer

# --- ESTADO ---
var is_attacking = false
var last_direction = Vector2(0, 1)
var active_item: ItemData = null
var hit_enemies = []
var is_dead = false
var is_in_knockback = false
const BUMP_FORCE = 100.0
var has_code_patch: bool = false

@export_group("Dash Settings")
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.15 # Duração curta para um dash rápido

var can_dash: bool = true
var is_dashing: bool = false

func _ready():
	health_updated.emit(health, max_health)
	mana_updated.emit(mana)
	# NOVO: Equipa as habilidades padrão ao iniciar o jogo
	if default_skill_q:
		equip_skill(default_skill_q, "q")
	if default_skill_e:
		equip_skill(default_skill_e, "e")
	

# --- NOVO: Função de Inventário ---
func add_item_to_inventory(item_data: ItemData):
	if not item_data:
		return

	# Verifica se o item já existe no inventário
	if inventory.has(item_data):
		if item_data.is_stackable:
			inventory[item_data]["quantity"] += 1
	else:
		inventory[item_data] = {"quantity": 1}

	# Define o item ativo caso ainda não tenha um
	if current_active_item == null:
		current_active_item = item_data

	# ✅ Corrigido: agora o sinal envia o inventário E o item ativo
	emit_signal("inventory_updated", inventory, current_active_item)

	print("Item adicionado ao inventário:", item_data.item_name)
	
# Esta função será conectada ao sinal 'item_collected' de qualquer item.
func _on_item_collected(item_data: ItemData):
	# Verificamos se o item coletado é o nosso Code Patch.
	# Usar o 'item_name' é uma forma simples e eficaz de identificá-lo.
	if item_data.item_name == "Code Patch":
		print("Player coletou o Code Patch!")
		has_code_patch = true
		
		# Futuramente, podemos adicionar um feedback aqui:
		# - Tocar um som especial de "item chave".
		# - hud.show_notification("Code Patch Adquirido!")

# Esta função será chamada pelo boss quando a interação for bem-sucedida.
func consume_code_patch():
	if has_code_patch:
		print("Player consumiu o Code Patch.")
		has_code_patch = false
	else:
		push_warning("Tentativa de consumir um Code Patch que o jogador não possui.")


func add_fragment_to_inventory(fragment_data: CodeFragmentData):
	var id = fragment_data.fragment_id
	if code_fragments_inventory.has(id):
		code_fragments_inventory[id]["quantity"] += 1
	else:
		code_fragments_inventory[id] = {
			"data": fragment_data,
			"quantity": 1
		}
	print("Fragmento de código coletado: '", fragment_data.fragment_text, "' | Quantidade: ", code_fragments_inventory[id]["quantity"])
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
	# Regeneração de Mana
	if mana < max_mana:
		mana += mana_regeneration_rate * delta
		mana = min(mana, max_mana)
		mana_updated.emit(mana, max_mana)

	# Lógica de Estados (Morte, Knockback, Ataque)
	if is_dead: return
	if is_in_knockback or is_attacking:
		velocity = velocity.move_toward(Vector2.ZERO, velocidade * 2 * delta)
		move_and_slide()
		return

	if is_dashing:
		return
	# Lógica de Movimento
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# NOVO: Checa pelo input do dash ANTES do movimento normal
	if Input.is_action_just_pressed("dash") and can_dash:
		_execute_dash(direction)
	else:
		# Lógica de Movimento Normal (só acontece se não usar o dash)
		if direction != Vector2.ZERO:
			velocity = direction.normalized() * velocidade
			last_direction = direction
		else:
			velocity = Vector2.ZERO
		
		move_and_slide()
		update_animation(direction)
	
	# Lógica de Inputs de Ação
	if Input.is_action_just_pressed("attack"):
		_execute_basic_attack()
	if Input.is_action_just_pressed("skill_q"):
		use_skill_q()
	if Input.is_action_just_pressed("skill_e"):
		use_skill_e()
	if Input.is_action_just_pressed("use_item"):
		use_active_item()


# --- Funções de Gerenciamento de Mana (NOVAS) ---
func use_mana(amount: int):
	mana -= amount
	mana = max(0, mana)
	mana_updated.emit(mana, max_mana)
	print("Mana gasta. Mana atual: ", mana)

func restore_mana(amount: int):
	mana += amount
	mana = min(mana, max_mana)
	mana_updated.emit(mana, max_mana)
	print("Mana restaurada. Mana atual: ", mana)
# NOVO: Função para o menu de skills chamar

# --- LÓGICA DE COMBATE BÁSICO ---
func _execute_basic_attack():
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

# --- LÓGICA DE HABILIDADES ---
func equip_skill(skill_data: SkillData, slot: String):
	# Desequipa do outro slot se a skill já estiver lá
	if slot == "q" and is_instance_valid(equipped_skill_e) and equipped_skill_e.skill_data == skill_data:
		equipped_skill_e.queue_free()
		equipped_skill_e = null
	if slot == "e" and is_instance_valid(equipped_skill_q) and equipped_skill_q.skill_data == skill_data:
		equipped_skill_q.queue_free()
		equipped_skill_q = null
		
	var skill_scene = skill_data.skill_scene.instantiate()
	skill_scene.player = self
	skill_scene.set_skill_data(skill_data)
	
	match slot:
		"q":
			if is_instance_valid(equipped_skill_q): equipped_skill_q.queue_free()
			equipped_skill_q = skill_scene
		"e":
			if is_instance_valid(equipped_skill_e): equipped_skill_e.queue_free()
			equipped_skill_e = skill_scene
	
	equipped_skills_container.add_child(skill_scene)
	print("Habilidade ", skill_data.skill_name, " equipada no slot ", slot.to_upper())
	equipped_skills_changed.emit(equipped_skill_q, equipped_skill_e)
# REESCRITO: Agora é um "disparador"
func use_skill_q():
	if is_instance_valid(equipped_skill_q):
		equipped_skill_q._execute()
		# AVISA A HUD SOBRE O COOLDOWN (LINHA QUE FALTAVA)
		emit_signal("skill_used", "q", equipped_skill_q.cooldown_time)

func use_skill_e():
	if is_instance_valid(equipped_skill_e):
		equipped_skill_e._execute()
		# NOVO: O player avisa a HUD sobre o cooldown
		emit_signal("skill_used", "e", equipped_skill_e.cooldown_time)

# --- Demais funções ---
# ... (todas as outras funções como `update_animation`, `take_damage`, `die`, etc., permanecem as mesmas)
# ... (as colei aqui para garantir que nada mais seja perdido)

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
	if body in hit_enemies:
		return
	
	# Agora o jogador pode atingir inimigos e loots (caixas, baús, etc)
	if body.is_in_group("enemies") or body.is_in_group("loots"):
		hit_enemies.append(body)
		
		var knockback_direction = (body.global_position - global_position).normalized()
		
		# Se o corpo tiver a função take_damage(), chamamos ela
		if body.has_method("take_damage"):
			body.take_damage(1, knockback_direction)
		
func take_damage(amount, knockback_direction = Vector2.ZERO, attacker = null):
	
	if is_instance_valid(equipped_skill_q) and equipped_skill_q is PacketAnalysisSkill:
		# 2. Tenta executar o parry, passando o atacante e o dano
		var parry_succeeded = await equipped_skill_q.try_parry_attack(attacker, amount)
		# 3. Se o parry foi bem-sucedido, interrompe a função aqui. Nenhum dano é levado.
		if parry_succeeded:
			return
			
	if is_instance_valid(equipped_skill_e) and equipped_skill_e is PacketAnalysisSkill:
		# 2. Tenta executar o parry, passando o atacante e o dano
		var parry_succeeded = await equipped_skill_e.try_parry_attack(attacker, amount)
		# 3. Se o parry foi bem-sucedido, interrompe a função aqui. Nenhum dano é levado.
		if parry_succeeded:
			return
			
			
	if is_dead:
		return
	health -= amount
	health_updated.emit(health, max_health)
	player_took_damage.emit()
	is_in_knockback = true
	velocity = knockback_direction * 80.0
	get_tree().create_timer(0.2).timeout.connect(on_knockback_finished)
	
	if health <= 0 and not is_dead:
		call_deferred("die")

func on_knockback_finished():
	is_in_knockback = false
		
func die():
	# Procura no inventário por um item com o nome "Backup de Integridade"
	var backup_item: ItemData = null
	for item in inventory.keys():
		if item.item_name == "Backup":
			backup_item = item
			break # Encontrou, pode parar de procurar

	# Se encontrou o item no inventário...
	if is_instance_valid(backup_item):
		print("Backup de Integridade consumido! O jogador sobreviveu.")
		
		# Consome o item do inventário
		remove_item_from_inventory(backup_item)
		
		# Restaura metade da vida e emite os sinais
		health = max_health / 2
		health_updated.emit(health, max_health)
		
		# Efeito visual/sonoro de reviver aqui
		
		return # Interrompe a função 'die', o jogador não morre.

	if is_dead: return
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
	
# --- Funções de Gerenciamento de Vida (NOVA) ---
# Adicione esta função para centralizar a cura
func restore_health(amount: int):
	health += amount
	health = min(health, max_health) # Garante que a vida não ultrapasse o máximo
	health_updated.emit(health, max_health)
	print("Vida restaurada. Vida atual: ", health)
# --- NOVAS Funções de Gerenciamento de Itens ---
# Adicione estas duas novas funções ao final do seu script
func use_active_item():
	if is_dead or not active_item:
		return

	print("Tentando usar o item: ", active_item.item_name)
	
	# Usa um 'match' para decidir o que fazer com base no efeito do item
	match active_item.item_name:
		"Poção de Vida":
			# NOVO: Verifica se a vida já está cheia
			if health >= max_health:
				print("Vida já está cheia! Não é possível usar a poção.")
				return # Interrompe a função aqui, o item não é consumido
			
			restore_health(active_item.effect_value)

		"Poção de Mana":
			# NOVO: Verifica se a mana já está cheia
			if mana >= max_mana:
				print("Mana já está cheia! Não é possível usar a poção.")
				return # Interrompe a função aqui, o item não é consumido
			
			restore_mana(active_item.effect_value)
		"Bomba Lógica":
			# Instancia a cena da bomba na posição do jogador
			var bomb_instance = preload("res://Scenes/Items/LogicBomb.tscn").instantiate()
			get_parent().add_child(bomb_instance)
			bomb_instance.global_position = global_position
		"Backup":
			print("Este item tem um efeito passivo e não pode ser usado activamente.")
			# Tocar um som de "erro" ou "falha" aqui é uma boa ideia.
			return # Interrompe a função aqui para que o item NÃO seja consumido.
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
	if upgrade_effect_id in unlocked_upgrade_ids: return

	print("Aplicando upgrade: ", upgrade_effect_id)
	
	# Passa o comando de upgrade para as skills equipadas
	if is_instance_valid(equipped_skill_q):
		equipped_skill_q._apply_upgrade(upgrade_effect_id)
	if is_instance_valid(equipped_skill_e):
		equipped_skill_e._apply_upgrade(upgrade_effect_id)

	unlocked_upgrade_ids.append(upgrade_effect_id)
# --- NOVAS FUNÇÕES ---

func _execute_dash(input_direction: Vector2):
	can_dash = false
	is_dashing = true
	dash_cooldown_timer.start()

	var dash_direction = input_direction
	# Se o jogador estiver parado, usa a última direção em que ele se moveu
	if dash_direction == Vector2.ZERO:
		dash_direction = last_direction

	# Usamos um tween para um movimento curto e preciso que não usa a física normal
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	
	# Calcula a posição final do dash
	var target_position = global_position + dash_direction.normalized() * dash_speed * dash_duration
	tween.tween_property(self, "global_position", target_position, dash_duration)
	
	# Toca uma animação de "dash" se tiver uma
	# animated_sprite.play("dash")
	
	# Quando o tween terminar, o estado de 'is_dashing' é resetado
	tween.finished.connect(func(): is_dashing = false)



func _on_dash_cooldown_timer_timeout():
	can_dash = true
	
