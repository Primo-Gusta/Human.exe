extends Skill
class_name FirewallSkill

# --- NÓS DA CENA ---
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var wall_node: Area2D = $Wall
@onready var wall_duration_timer: Timer = $Wall/DurationTimer
@onready var wall_sprite: AnimatedSprite2D = $Wall/AnimatedSprite2D

# --- STATS DA HABILIDADE ---
var mana_cost: int
var damage_per_second: int
var wall_duration: float
var cooldown_time: float
var can_use: bool = true

# --- UPGRADES ---
var slow_on_hit_unlocked: bool = false
var damage_pulse_unlocked: bool = false

# --- LÓGICA DE DANO ---
var enemies_in_area: Array[Node2D] = []

func _ready():
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	wall_duration_timer.timeout.connect(_on_wall_duration_finished)
	
	wall_node.body_entered.connect(_on_wall_body_entered)
	wall_node.body_exited.connect(_on_wall_body_exited)
	
	_deactivate_wall()

func _process(delta):
	# Aplica dano contínuo a cada inimigo que está dentro da área
	for enemy in enemies_in_area:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(damage_per_second * delta, Vector2.ZERO)

func set_skill_data(new_data: SkillData):
	self.skill_data = new_data
	if not skill_data: return
	
	self.mana_cost = skill_data.mana_cost
	self.cooldown_time = skill_data.cooldown_time
	self.damage_per_second = skill_data.base_damage
	self.wall_duration = skill_data.base_duration

	if is_instance_valid(player):
		for upgrade_id in player.unlocked_upgrade_ids:
			_apply_upgrade(upgrade_id)

func _execute():
	if not can_use or not is_instance_valid(player) or player.mana < mana_cost:
		return

	can_use = false
	cooldown_timer.wait_time = cooldown_time
	cooldown_timer.start()
	player.use_mana(skill_data.mana_cost)
	
	var spawn_distance = 25.0
	var player_direction = player.last_direction
	
	# --- LÓGICA DE ROTAÇÃO MANTIDA ---
	# Se o jogador está a olhar mais na horizontal (esquerda/direita)...
	if abs(player_direction.x) > abs(player_direction.y):
		# ...a parede fica na vertical (90 graus).
		wall_node.rotation_degrees = 90
	else:
		# ...senão (cima/baixo), a parede fica na horizontal (0 graus).
		wall_node.rotation_degrees = 0
	
	wall_node.global_position = player.global_position + (player_direction.normalized() * spawn_distance)
	
	_activate_wall()

# --- Funções de Gestão e Lógica Interna ---

func _activate_wall():
	wall_node.visible = true
	wall_node.get_node("CollisionShape2D").disabled = false
	wall_node.get_node("StaticBody2D/CollisionShape2D").disabled = false
	set_process(true) # Começa a aplicar dano
	
	# Toca a animação "fire" em loop
	wall_sprite.play("fire")
	
	wall_duration_timer.wait_time = wall_duration
	wall_duration_timer.start()

func _deactivate_wall():
	wall_node.visible = false
	wall_node.get_node("CollisionShape2D").disabled = true
	wall_node.get_node("StaticBody2D/CollisionShape2D").disabled = true
	set_process(false)
	enemies_in_area.clear()
	
	# Para a animação para poupar performance
	wall_sprite.stop()

func _on_wall_duration_finished():
	_deactivate_wall()
	
func _on_cooldown_finished():
	can_use = true

func _apply_upgrade(upgrade_id: String):
	match upgrade_id:
		"firewall_slow":
			slow_on_hit_unlocked = true
		"firewall_pulse":
			damage_pulse_unlocked = true
	
# --- Funções de Detecção de Dano ---

func _on_wall_body_entered(body):
	if body.is_in_group("enemies") and not body in enemies_in_area:
		enemies_in_area.append(body)
		
		# Aplica o slow do upgrade, se desbloqueado
		if slow_on_hit_unlocked and body.has_method("apply_slow"):
			body.apply_slow(3.0)

func _on_wall_body_exited(body):
	if body in enemies_in_area:
		enemies_in_area.erase(body)
