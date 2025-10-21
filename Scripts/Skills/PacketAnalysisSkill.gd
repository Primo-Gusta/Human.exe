extends Skill
class_name PacketAnalysisSkill

# --- NÓS DA CENA ---
@onready var parry_timer: Timer = $ParryTimer
@onready var parry_vfx: AnimatedSprite2D = $ParryVFX

# --- STATS DA HABILIDADE ---
var parry_window: float = 0.3
var can_parry: bool = true
var cooldown_time: float = 2.0
var mana_cost: int 
var can_use: bool = true

# Upgrades
var feedback_loop: bool = false
var data_siphon: bool = false
var mana_restore: int = 2  # Valor restaurado com Data Siphon
var damage_reflect: int = 1 # Valor refletido com Feedback Loop

func _ready():
	parry_timer.wait_time = parry_window
	parry_timer.one_shot = true
	parry_vfx.animation_finished.connect(func(): parry_vfx.visible = false)

func _execute():
	if not can_parry or not is_instance_valid(player):
		return
	
	can_parry = false
	parry_timer.start()
	# A função show_parry_effect para a "janela" pode ser removida se não for mais necessária
	print("Parry ativado! Janela de ", parry_window, " segundos.")
	
	await get_tree().create_timer(cooldown_time).timeout # Corrigido para usar cooldown_time
	can_parry = true

	# Reseta cooldown geral
	await get_tree().create_timer(0.5).timeout
	can_parry = true

func try_parry_attack(attacker: Node, damage: int) -> bool:
	if parry_timer.is_stopped():
		return false

	print("Parry bem-sucedido!")
	
	# --- ATIVAÇÃO DO VFX ---
	# Posiciona o VFX no local do jogador e toca a animação
	if is_instance_valid(parry_vfx):
		parry_vfx.global_position = player.global_position
		parry_vfx.visible = true
		parry_vfx.play("impact")
	
	# --- LÓGICA DE HIT STOP (continua a mesma) ---
	get_tree().paused = true
	var hit_stop_timer = get_tree().create_timer(0.1, true, false, true)
	await hit_stop_timer.timeout
	get_tree().paused = false
	
	# O resto da sua lógica de parry continua aqui...
	# Atordoa inimigo
	if attacker.has_method("apply_stun"):
		attacker.apply_stun(1.5)
	
	# Feedback Loop: reflete dano
	if feedback_loop and attacker.has_method("take_damage"):
		attacker.take_damage(damage_reflect, (attacker.global_position - player.global_position).normalized())

	# Data Siphon: restaura mana
	if data_siphon and is_instance_valid(player):
		player.restore_mana(mana_restore)
	
	parry_timer.stop()
	return true
# Upgrade
func _apply_upgrade(upgrade_id: String):
	match upgrade_id:
		"feedback_loop":
			feedback_loop = true
		"data_siphon":
			data_siphon = true


func _on_parry_timer_timeout() -> void:
	pass # Replace with function body.
	
func set_skill_data(new_data: SkillData):
	self.skill_data = new_data # Armazena a referência ao recurso .tres
	if not skill_data: return
	
	# Popula os stats da habilidade com os valores base do Resource
	self.mana_cost = skill_data.mana_cost
	self.cooldown_time = skill_data.cooldown_time
	# (Adicione outras variáveis base que possa ter no seu SkillData.tres)
	
	# Aplica upgrades que o jogador já possa ter desbloqueado
	if is_instance_valid(player):
		for upgrade_id in player.unlocked_upgrade_ids:
			_apply_upgrade(upgrade_id)
