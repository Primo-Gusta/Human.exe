extends Skill
class_name AttackLoopSkill

# --- NÓS DA CENA ---
@onready var cooldown_timer: Timer = $CooldownTimer

# --- PRELOADS ---
const RicochetProjectileScene = preload("res://Scenes/Projectiles/RicochetProjectile.tscn")

# --- STATS DA HABILIDADE ---
# Estes valores serão preenchidos pela função set_skill_data
var mana_cost: int
var damage: int
var max_bounces: int
var cooldown_time: float
var can_use: bool = true

func _ready():
	cooldown_timer.timeout.connect(_on_cooldown_finished)

# Esta função é chamada pelo Player.gd ao equipar a skill
func set_skill_data(new_data: SkillData):
	skill_data = new_data
	if not skill_data: return
	
	# Popula os stats da habilidade com os valores base do Resource
	self.mana_cost = skill_data.mana_cost
	self.cooldown_time = skill_data.cooldown_time
	self.damage = skill_data.base_damage
	self.max_bounces = skill_data.base_bounces
	
	# Aplica upgrades que o jogador já possa ter desbloqueado
	if is_instance_valid(player):
		for upgrade_id in player.unlocked_upgrade_ids:
			_apply_upgrade(upgrade_id)

# Esta função SOBRESCREVE a função "_execute" do nosso "contrato"
func _execute():
	if not can_use or not is_instance_valid(player) or player.mana < mana_cost:
		if is_instance_valid(player) and player.mana < mana_cost:
			print("Mana insuficiente para o Loop de Dano!")
		return

	can_use = false
	player.use_mana(mana_cost)
	cooldown_timer.wait_time = cooldown_time
	cooldown_timer.start()
	# O Player.gd é quem avisa a HUD sobre o cooldown

	print("Executando Loop de Dano (versão componente)!")

	var projectile_instance = RicochetProjectileScene.instantiate()
	get_parent().add_child(projectile_instance)
	
	projectile_instance.global_position = player.global_position
	projectile_instance.setup_projectile(player.last_direction, damage, max_bounces)

func _on_cooldown_finished():
	can_use = true

# Esta função SOBRESCREVE a função de upgrade do nosso "contrato"
func _apply_upgrade(upgrade_id: String):
	match upgrade_id:
		"loop_bounces_1":
			max_bounces += 1
			print("Stat de ricochetes do Loop de Dano atualizado para: ", max_bounces)
		# Adicione outros 'case' para upgrades futuros desta skill aqui
