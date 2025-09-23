extends CharacterBody2D

# --- SINAIS ---
signal health_updated(current_health)
signal player_died
signal player_took_damage
signal mana_updated(current_mana)
signal inventory_updated(inventory_data: Dictionary, current_active_item: ItemData)
signal active_item_changed(item_data: ItemData)
signal code_fragments_inventory_updated(fragments_inventory: Dictionary)
# NOVO: Avisa a HUD para atualizar os ícones das skills
signal equipped_skills_changed(equipped_q: SkillData, equipped_e: SkillData)

# --- ATRIBUTOS ---
@export var velocidade = 150.0
var health = 10
var max_health = 10
var mana = 20
var max_mana = 20
@export var mana_regeneration_rate: float = 0.5

# --- INVENTÁRIOS ---
var inventory: Dictionary = {}
var code_fragments_inventory: Dictionary = {}
var unlocked_upgrade_ids: Array[String] = []

# --- HABILIDADES EQUIPADAS ---
var equipped_skill_q: Skill = null # Agora armazena a INSTÂNCIA da cena da skill
var equipped_skill_e: Skill = null # Agora armazena a INSTÂNCIA da cena da skill

# --- STATS DAS HABILIDADES (Agora são independentes dos slots) ---
var skill_pulse_damage = 1
var skill_pulse_range = 60
var skill_loop_damage = 1
var skill_loop_max_bounces = 2

# --- PRELOADS E REFERÊNCIAS ---
@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox_shape = $Hitbox/CollisionShape2D
# REMOVIDO: O visual do pulso agora é parte da cena da habilidade
# @onready var skill_q_pulse_visual = $SkillQ_PulseVisual

# --- ESTADO ---
var is_attacking = false
var last_direction = Vector2(0, 1)
var active_item: ItemData = null
var hit_enemies = []
var is_dead = false
var is_in_knockback = false

# --- NÓS PARA ORGANIZAÇÃO ---
@onready var equipped_skills_container = $EquippedSkillsContainer

func _ready():
	health_updated.emit(health)
	mana_updated.emit(mana)

func _physics_process(delta):
	# ... (lógica de regeneração de mana, movimento, ataque, etc. permanece a mesma)
	if mana < max_mana:
		mana += mana_regeneration_rate * delta
		mana = min(mana, max_mana)
		mana_updated.emit(mana)
	
	if is_dead or is_in_knockback or is_attacking:
		# Lógica de movimento simplificada quando em outros estados
		if is_in_knockback or is_attacking:
			velocity = velocity.move_toward(Vector2.ZERO, velocidade * 2 * delta)
			move_and_slide()
		return

	# Lógica de input
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		velocity = direction.normalized() * velocidade
		last_direction = direction
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	update_animation(direction)
	
	if Input.is_action_just_pressed("attack"):
		_execute_basic_attack() # Movido para uma função por organização
	if Input.is_action_just_pressed("skill_q"):
		use_skill_q()
	if Input.is_action_just_pressed("skill_e"):
		use_skill_e()
	if Input.is_action_just_pressed("use_item"):
		use_active_item()

# --- NOVA LÓGICA DE EQUIPAR HABILIDADES ---
func equip_skill(skill_data: SkillData, slot: String):
	# Desequipa a skill do outro slot se ela já estiver lá
	if slot == "q" and is_instance_valid(equipped_skill_e) and equipped_skill_e.skill_data == skill_data:
		equipped_skill_e.queue_free()
		equipped_skill_e = null
	if slot == "e" and is_instance_valid(equipped_skill_q) and equipped_skill_q.skill_data == skill_data:
		equipped_skill_q.queue_free()
		equipped_skill_q = null
		
	# Instancia a cena da habilidade
	var skill_scene = skill_data.skill_scene.instantiate()
	# Dá a ela as referências que precisa
	skill_scene.player = self
	skill_scene.skill_data = skill_data
	
	# Equipa no slot desejado, limpando o anterior
	match slot:
		"q":
			if is_instance_valid(equipped_skill_q):
				equipped_skill_q.queue_free()
			equipped_skill_q = skill_scene
		"e":
			if is_instance_valid(equipped_skill_e):
				equipped_skill_e.queue_free()
			equipped_skill_e = skill_scene
	
	# Adiciona a instância da habilidade como filha do container
	equipped_skills_container.add_child(skill_scene)
	
	print("Habilidade ", skill_data.skill_name, " equipada no slot ", slot.to_upper())
	# Avisa a HUD para atualizar os ícones
	equipped_skills_changed.emit(equipped_skill_q, equipped_skill_e)

# --- FUNÇÕES DE USO DE SKILL REATORADAS ---
func use_skill_q():
	if is_instance_valid(equipped_skill_q):
		equipped_skill_q._execute()

func use_skill_e():
	if is_instance_valid(equipped_skill_e):
		equipped_skill_e._execute()

# --- O resto do script (inventário, tomar dano, upgrades, etc.) ---
# ... (a maior parte do seu código anterior se encaixa aqui sem alterações)
# Lembre-se que 'apply_skill_upgrade' agora precisa modificar as variáveis de stats,
# como 'skill_pulse_damage', e talvez passar essa mudança para a instância da skill equipada.
